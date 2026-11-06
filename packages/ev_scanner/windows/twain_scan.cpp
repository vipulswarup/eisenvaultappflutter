#include <windows.h>

#include <algorithm>
#include <cstring>

#include "scan_core.h"
#include "third_party/twain.h"

namespace evscan {
namespace {

constexpr wchar_t kWndClass[] = L"EvScannerTwainHost";

struct Dsm {
  HMODULE lib = nullptr;
  DSMENTRYPROC entry = nullptr;
  TW_IDENTITY app = {};
  HWND hwnd = nullptr;
  bool open = false;
};

HWND CreateHostWindow() {
  static bool registered = false;
  if (!registered) {
    WNDCLASSW wc = {};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kWndClass;
    RegisterClassW(&wc);
    registered = true;
  }
  return CreateWindowExW(0, kWndClass, L"EisenVault scan", WS_POPUP, 0, 0, 1, 1,
                         nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
}

void FillAppIdentity(TW_IDENTITY* id) {
  memset(id, 0, sizeof(*id));
  id->Version.MajorNum = 2;
  id->Version.MinorNum = 0;
  id->Version.Language = TWLG_ENGLISH_USA;
  id->Version.Country = TWCY_USA;
  strcpy_s(id->Version.Info, "2.0");
  id->ProtocolMajor = TWON_PROTOCOLMAJOR;
  id->ProtocolMinor = TWON_PROTOCOLMINOR;
  id->SupportedGroups = DF_APP2 | DG_IMAGE | DG_CONTROL;
  strcpy_s(id->Manufacturer, "EisenVault");
  strcpy_s(id->ProductFamily, "EisenVault Desktop");
  strcpy_s(id->ProductName, "EisenVault Desktop");
}

bool OpenDsm(Dsm* d, const std::wstring& dir, ScanError* err) {
  // Ship the 64-bit TWAINDSM.dll next to the app; fall back to the system one.
  std::wstring path = dir + L"\\TWAINDSM.dll";
  d->lib = LoadLibraryW(path.c_str());
  if (!d->lib) d->lib = LoadLibraryW(L"TWAINDSM.dll");
  if (!d->lib) {
    *err = {"driverMissing", "The TWAIN Data Source Manager is missing."};
    return false;
  }
  d->entry = (DSMENTRYPROC)GetProcAddress(d->lib, "DSM_Entry");
  if (!d->entry) {
    *err = {"driverMissing", "The TWAIN Data Source Manager is damaged."};
    return false;
  }
  FillAppIdentity(&d->app);
  d->hwnd = CreateHostWindow();
  if (d->entry(&d->app, nullptr, DG_CONTROL, DAT_PARENT, MSG_OPENDSM,
               &d->hwnd) != TWRC_SUCCESS) {
    *err = {"driverMissing", "The TWAIN Data Source Manager could not start."};
    return false;
  }
  d->open = true;
  return true;
}

void CloseDsm(Dsm* d) {
  if (d->open) {
    d->entry(&d->app, nullptr, DG_CONTROL, DAT_PARENT, MSG_CLOSEDSM, &d->hwnd);
  }
  if (d->hwnd) DestroyWindow(d->hwnd);
  if (d->lib) FreeLibrary(d->lib);
  *d = Dsm();
}

std::vector<TW_IDENTITY> EnumSources(Dsm* d) {
  std::vector<TW_IDENTITY> out;
  TW_IDENTITY ds = {};
  TW_UINT16 rc =
      d->entry(&d->app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_GETFIRST, &ds);
  while (rc == TWRC_SUCCESS) {
    out.push_back(ds);
    rc = d->entry(&d->app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_GETNEXT, &ds);
  }
  return out;
}

TW_UINT16 ConditionCode(Dsm* d, TW_IDENTITY* ds) {
  TW_STATUS st = {};
  d->entry(&d->app, ds, DG_CONTROL, DAT_STATUS, MSG_GET, &st);
  return st.ConditionCode;
}

ScanError MapCondition(TW_UINT16 cc) {
  switch (cc) {
    case TWCC_PAPERJAM:
    case TWCC_PAPERDOUBLEFEED:
      return {"paperJam", "Paper jam. Clear the jam and try again."};
    case TWCC_NOMEDIA:
      return {"feederEmpty", "The document feeder is empty. Load paper and try again."};
    case TWCC_CHECKDEVICEONLINE:
      return {"driverMissing",
              "The scanner is offline. Check the cable and power, and that its driver is installed."};
    case TWCC_BUMMER:
    case TWCC_SEQERROR:
      return {"deviceBusy", "The scanner is busy. Wait for it to finish, then try again."};
    default:
      return {"failed", "The scanner reported error " + std::to_string(cc) + "."};
  }
}

// Capability helpers -------------------------------------------------------

bool SetCapOne(Dsm* d, TW_IDENTITY* ds, TW_UINT16 cap, TW_UINT16 type,
               TW_UINT32 value) {
  TW_CAPABILITY c = {};
  c.Cap = cap;
  c.ConType = TWON_ONEVALUE;
  c.hContainer = GlobalAlloc(GHND, sizeof(TW_ONEVALUE));
  if (!c.hContainer) return false;
  auto* one = (pTW_ONEVALUE)GlobalLock(c.hContainer);
  one->ItemType = type;
  one->Item = value;
  GlobalUnlock(c.hContainer);
  TW_UINT16 rc = d->entry(&d->app, ds, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &c);
  GlobalFree(c.hContainer);
  return rc == TWRC_SUCCESS;
}

bool SetCapFix32(Dsm* d, TW_IDENTITY* ds, TW_UINT16 cap, double v) {
  TW_FIX32 f;
  TW_INT32 whole = (TW_INT32)(v * 65536.0 + 0.5);
  f.Whole = (TW_INT16)(whole >> 16);
  f.Frac = (TW_UINT16)(whole & 0xFFFF);
  TW_UINT32 raw = 0;
  memcpy(&raw, &f, sizeof(f));
  return SetCapOne(d, ds, cap, TWTY_FIX32, raw);
}

// Reads the first/current value of a capability. Returns false if unsupported.
bool GetCapValue(Dsm* d, TW_IDENTITY* ds, TW_UINT16 cap, TW_UINT32* value) {
  TW_CAPABILITY c = {};
  c.Cap = cap;
  c.ConType = TWON_DONTCARE16;
  if (d->entry(&d->app, ds, DG_CONTROL, DAT_CAPABILITY, MSG_GETCURRENT, &c) !=
      TWRC_SUCCESS || !c.hContainer) {
    return false;
  }
  bool ok = false;
  void* p = GlobalLock(c.hContainer);
  if (p) {
    if (c.ConType == TWON_ONEVALUE) {
      *value = ((pTW_ONEVALUE)p)->Item;
      ok = true;
    } else if (c.ConType == TWON_ENUMERATION) {
      auto* e = (pTW_ENUMERATION)p;
      if (e->NumItems > 0) {
        *value = e->ItemList[0];
        ok = true;
      }
    }
    GlobalUnlock(c.hContainer);
  }
  GlobalFree(c.hContainer);
  return ok;
}

bool OpenSource(Dsm* d, TW_IDENTITY* ds) {
  return d->entry(&d->app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_OPENDS, ds) ==
         TWRC_SUCCESS;
}

void CloseSource(Dsm* d, TW_IDENTITY* ds) {
  d->entry(&d->app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_CLOSEDS, ds);
}

}  // namespace

std::vector<DeviceInfo> TwainListDevices(const std::wstring& dsm_dir,
                                         ScanError* error) {
  std::vector<DeviceInfo> out;
  Dsm d;
  if (!OpenDsm(&d, dsm_dir, error)) {
    CloseDsm(&d);
    return out;
  }
  for (auto src : EnumSources(&d)) {
    DeviceInfo info;
    info.name = src.ProductName;
    info.id = std::string("twain:") + src.ProductName;
    TW_IDENTITY ds = src;
    if (OpenSource(&d, &ds)) {
      TW_UINT32 v = 0;
      info.has_feeder = GetCapValue(&d, &ds, CAP_FEEDERENABLED, &v);
      info.has_duplex = GetCapValue(&d, &ds, CAP_DUPLEX, &v) && v != TWDX_NONE;
      CloseSource(&d, &ds);
    }
    out.push_back(info);
  }
  CloseDsm(&d);
  return out;
}

ScanOutcome TwainScan(const std::wstring& dsm_dir, const ScanParams& p,
                      const ProgressFn& progress) {
  ScanOutcome out;
  Dsm d;
  if (!OpenDsm(&d, dsm_dir, &out.error)) {
    CloseDsm(&d);
    return out;
  }
  const std::string wanted = p.device_id.substr(strlen("twain:"));
  TW_IDENTITY ds = {};
  bool found = false;
  for (auto src : EnumSources(&d)) {
    if (wanted == src.ProductName) {
      ds = src;
      found = true;
      break;
    }
  }
  if (!found || !OpenSource(&d, &ds)) {
    out.error = {"driverMissing",
                 "The scanner could not be opened. Check it is connected and "
                 "its driver is installed."};
    CloseDsm(&d);
    return out;
  }

  const bool feeder = p.source != "flatbed";
  if (!p.use_own_dialog) {
    SetCapOne(&d, &ds, CAP_INDICATORS, TWTY_BOOL, FALSE);
    SetCapOne(&d, &ds, ICAP_UNITS, TWTY_UINT16, TWUN_INCHES);
    SetCapOne(&d, &ds, CAP_XFERCOUNT, TWTY_INT16, (TW_UINT16)-1);
    SetCapOne(&d, &ds, CAP_FEEDERENABLED, TWTY_BOOL, feeder ? TRUE : FALSE);
    if (feeder) {
      SetCapOne(&d, &ds, CAP_AUTOFEED, TWTY_BOOL, TRUE);
      SetCapOne(&d, &ds, CAP_DUPLEXENABLED, TWTY_BOOL,
                p.source == "duplex" ? TRUE : FALSE);
      TW_UINT32 loaded = 1;
      if (GetCapValue(&d, &ds, CAP_FEEDERLOADED, &loaded) && !loaded) {
        out.error = {"feederEmpty",
                     "The document feeder is empty. Load paper and try again."};
        CloseSource(&d, &ds);
        CloseDsm(&d);
        return out;
      }
    }
    TW_UINT16 pixel = p.color_mode == "grayscale"       ? TWPT_GRAY
                      : p.color_mode == "blackAndWhite" ? TWPT_BW
                                                        : TWPT_RGB;
    SetCapOne(&d, &ds, ICAP_PIXELTYPE, TWTY_UINT16, pixel);
    SetCapFix32(&d, &ds, ICAP_XRESOLUTION, p.dpi);
    SetCapFix32(&d, &ds, ICAP_YRESOLUTION, p.dpi);
    SetCapOne(&d, &ds, ICAP_SUPPORTEDSIZES, TWTY_UINT16,
              p.width_mm > 212 ? TWSS_USLETTER : TWSS_A4);
  }

  TW_USERINTERFACE ui = {};
  ui.ShowUI = p.use_own_dialog ? TRUE : FALSE;
  ui.ModalUI = TRUE;
  ui.hParent = d.hwnd;
  TW_UINT16 rc = d.entry(&d.app, &ds, DG_CONTROL, DAT_USERINTERFACE,
                         MSG_ENABLEDS, &ui);
  if (rc == TWRC_FAILURE) {
    out.error = MapCondition(ConditionCode(&d, &ds));
    CloseSource(&d, &ds);
    CloseDsm(&d);
    return out;
  }

  bool done = false;
  int page = 0;
  MSG msg;
  while (!done && GetMessageW(&msg, nullptr, 0, 0)) {
    TW_EVENT ev = {};
    ev.pEvent = &msg;
    ev.TWMessage = MSG_NULL;
    TW_UINT16 r = d.entry(&d.app, &ds, DG_CONTROL, DAT_EVENT, MSG_PROCESSEVENT, &ev);
    if (r == TWRC_NOTDSEVENT) {
      TranslateMessage(&msg);
      DispatchMessageW(&msg);
    }
    if (ev.TWMessage == MSG_CLOSEDSREQ || ev.TWMessage == MSG_CLOSEDSOK) {
      done = true;
    } else if (ev.TWMessage == MSG_XFERREADY) {
      bool more = true;
      while (more) {
        if (g_cancel) {
          TW_PENDINGXFERS pend = {};
          d.entry(&d.app, &ds, DG_CONTROL, DAT_PENDINGXFERS, MSG_RESET, &pend);
          out.error = {"cancelled", "Scan cancelled."};
          more = false;
          done = true;
          break;
        }
        TW_MEMREF dib = nullptr;
        TW_UINT16 x = d.entry(&d.app, &ds, DG_IMAGE, DAT_IMAGENATIVEXFER,
                              MSG_GET, &dib);
        if (x == TWRC_XFERDONE) {
          HGLOBAL h = (HGLOBAL)dib;
          void* mem = GlobalLock(h);
          wchar_t name[32];
          swprintf_s(name, L"page-%03d.png", ++page);
          std::wstring path = p.output_dir + L"\\" + name;
          bool saved = mem && SaveDibAsPng(mem, GlobalSize(h), path);
          if (mem) GlobalUnlock(h);
          GlobalFree(h);
          if (saved) {
            out.pages.push_back(path);
            if (progress) progress((int)out.pages.size());
          }
        } else if (x == TWRC_FAILURE) {
          out.error = MapCondition(ConditionCode(&d, &ds));
        }
        TW_PENDINGXFERS pend = {};
        if (d.entry(&d.app, &ds, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER,
                    &pend) != TWRC_SUCCESS) {
          more = false;
        } else {
          more = pend.Count != 0;
        }
        if (x == TWRC_FAILURE || x == TWRC_CANCEL) {
          TW_PENDINGXFERS reset = {};
          d.entry(&d.app, &ds, DG_CONTROL, DAT_PENDINGXFERS, MSG_RESET, &reset);
          more = false;
        }
      }
      done = true;
    }
  }
  d.entry(&d.app, &ds, DG_CONTROL, DAT_USERINTERFACE, MSG_DISABLEDS, &ui);
  CloseSource(&d, &ds);
  CloseDsm(&d);

  if (!out.pages.empty() && out.error.code != "cancelled") {
    out.ok = true;
    out.error = {};
  } else if (out.error.code.empty()) {
    out.error = {"noPages", "The scanner returned no pages."};
  }
  return out;
}

}  // namespace evscan
