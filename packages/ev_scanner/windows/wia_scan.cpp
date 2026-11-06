#include <windows.h>

#include <shlwapi.h>
#include <wia.h>
#include <wrl/client.h>

#include <atomic>

#include "scan_core.h"

using Microsoft::WRL::ComPtr;

namespace evscan {
namespace {

// WIA error codes (wiadef.h values, spelled out for clarity).
constexpr HRESULT kPaperEmpty = (HRESULT)0x80210003;
constexpr HRESULT kPaperJam = (HRESULT)0x80210002;
constexpr HRESULT kOffline = (HRESULT)0x80210005;
constexpr HRESULT kBusy = (HRESULT)0x80210006;
constexpr HRESULT kCoverOpen = (HRESULT)0x80210016;

ScanError MapHr(HRESULT hr) {
  if (hr == kPaperEmpty)
    return {"feederEmpty", "The document feeder is empty. Load paper and try again."};
  if (hr == kPaperJam) return {"paperJam", "Paper jam. Clear the jam and try again."};
  if (hr == kCoverOpen) return {"failed", "The scanner cover is open."};
  if (hr == kBusy)
    return {"deviceBusy", "The scanner is busy. Wait for it to finish, then try again."};
  if (hr == kOffline)
    return {"driverMissing",
            "The scanner is offline. Check the cable and power, and that its driver is installed."};
  char buf[64];
  sprintf_s(buf, "The scan failed (WIA error 0x%08lX).", (unsigned long)hr);
  return {"failed", buf};
}

bool ReadString(IWiaPropertyStorage* s, PROPID id, std::wstring* out) {
  PROPSPEC spec = {PRSPEC_PROPID};
  spec.propid = id;
  PROPVARIANT v;
  PropVariantInit(&v);
  bool ok = false;
  if (s->ReadMultiple(1, &spec, &v) == S_OK && v.vt == VT_BSTR && v.bstrVal) {
    *out = v.bstrVal;
    ok = true;
  }
  PropVariantClear(&v);
  return ok;
}

bool ReadLong(IWiaPropertyStorage* s, PROPID id, LONG* out) {
  PROPSPEC spec = {PRSPEC_PROPID};
  spec.propid = id;
  PROPVARIANT v;
  PropVariantInit(&v);
  bool ok = false;
  if (s->ReadMultiple(1, &spec, &v) == S_OK && (v.vt == VT_I4 || v.vt == VT_UI4)) {
    *out = v.lVal;
    ok = true;
  }
  PropVariantClear(&v);
  return ok;
}

void WriteLong(IWiaPropertyStorage* s, PROPID id, LONG value) {
  PROPSPEC spec = {PRSPEC_PROPID};
  spec.propid = id;
  PROPVARIANT v;
  PropVariantInit(&v);
  v.vt = VT_I4;
  v.lVal = value;
  s->WriteMultiple(1, &spec, &v, WIA_IPA_FIRST);
}

bool ReadGuid(IWiaPropertyStorage* s, PROPID id, GUID* out) {
  PROPSPEC spec = {PRSPEC_PROPID};
  spec.propid = id;
  PROPVARIANT v;
  PropVariantInit(&v);
  bool ok = false;
  if (s->ReadMultiple(1, &spec, &v) == S_OK && v.vt == VT_CLSID && v.puuid) {
    *out = *v.puuid;
    ok = true;
  }
  PropVariantClear(&v);
  return ok;
}

class Callback : public IWiaTransferCallback {
 public:
  Callback(const std::wstring& dir, const ProgressFn& progress)
      : dir_(dir), progress_(progress) {}
  std::vector<std::wstring> pages;

  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (riid == IID_IUnknown || riid == IID_IWiaTransferCallback) {
      *ppv = static_cast<IWiaTransferCallback*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
  STDMETHODIMP_(ULONG) AddRef() override { return ++refs_; }
  STDMETHODIMP_(ULONG) Release() override {
    ULONG r = --refs_;
    if (r == 0) delete this;
    return r;
  }
  STDMETHODIMP TransferCallback(LONG, WiaTransferParams* p) override {
    if (g_cancel) return S_FALSE;  // S_FALSE cancels the transfer.
    if (p && p->lMessage == WIA_TRANSFER_MSG_END_OF_STREAM && progress_) {
      progress_((int)pages.size());
    }
    return S_OK;
  }
  STDMETHODIMP GetNextStream(LONG, BSTR, BSTR, IStream** dest) override {
    wchar_t name[32];
    swprintf_s(name, L"page-%03d.png", (int)pages.size() + 1);
    std::wstring path = dir_ + L"\\" + name;
    HRESULT hr = SHCreateStreamOnFileEx(path.c_str(), STGM_CREATE | STGM_WRITE,
                                        FILE_ATTRIBUTE_NORMAL, TRUE, nullptr,
                                        dest);
    if (SUCCEEDED(hr)) pages.push_back(path);
    return hr;
  }

 private:
  std::atomic<ULONG> refs_{1};
  std::wstring dir_;
  ProgressFn progress_;
};

}  // namespace

std::vector<DeviceInfo> WiaListDevices(ScanError* error) {
  std::vector<DeviceInfo> out;
  HRESULT init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  {
    ComPtr<IWiaDevMgr2> mgr;
    ComPtr<IEnumWIA_DEV_INFO> en;
    if (FAILED(CoCreateInstance(CLSID_WiaDevMgr2, nullptr, CLSCTX_LOCAL_SERVER,
                                IID_PPV_ARGS(&mgr))) ||
        FAILED(mgr->EnumDeviceInfo(WIA_DEVINFO_ENUM_LOCAL, &en))) {
      if (error) *error = {"driverMissing", "Windows Image Acquisition is not available."};
    } else {
      ComPtr<IWiaPropertyStorage> info;
      ULONG n = 0;
      while (en->Next(1, &info, &n) == S_OK && n == 1) {
        std::wstring id, name;
        if (ReadString(info.Get(), WIA_DIP_DEV_ID, &id)) {
          ReadString(info.Get(), WIA_DIP_DEV_NAME, &name);
          DeviceInfo d;
          d.id = "wia:" + Utf8(id);
          d.name = Utf8(name.empty() ? id : name);
          LONG caps = 0;
          ComPtr<IWiaItem2> root;
          ComPtr<IWiaPropertyStorage> ps;
          BSTR bid = SysAllocString(id.c_str());
          if (SUCCEEDED(mgr->CreateDevice(0, bid, &root)) &&
              SUCCEEDED(root.As(&ps)) &&
              ReadLong(ps.Get(), WIA_DPS_DOCUMENT_HANDLING_CAPABILITIES, &caps)) {
            d.has_feeder = (caps & FEEDER) != 0;
            d.has_duplex = (caps & DUPLEX) != 0;
          }
          SysFreeString(bid);
          out.push_back(d);
        }
        info.Reset();
      }
    }
  }
  if (SUCCEEDED(init)) CoUninitialize();
  return out;
}

ScanOutcome WiaScan(const ScanParams& p, const ProgressFn& progress) {
  ScanOutcome out;
  HRESULT init = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  [&] {
    std::wstring id = Wide(p.device_id.substr(strlen("wia:")));
    ComPtr<IWiaDevMgr2> mgr;
    ComPtr<IWiaItem2> root;
    if (FAILED(CoCreateInstance(CLSID_WiaDevMgr2, nullptr, CLSCTX_LOCAL_SERVER,
                                IID_PPV_ARGS(&mgr)))) {
      out.error = {"driverMissing", "Windows Image Acquisition is not available."};
      return;
    }
    BSTR bid = SysAllocString(id.c_str());
    HRESULT hr = mgr->CreateDevice(0, bid, &root);
    SysFreeString(bid);
    if (FAILED(hr)) {
      out.error = MapHr(hr);
      return;
    }
    const bool feeder = p.source != "flatbed";
    ComPtr<IWiaPropertyStorage> rootProps;
    root.As(&rootProps);
    if (feeder) {
      LONG status = 0;
      if (ReadLong(rootProps.Get(), WIA_DPS_DOCUMENT_HANDLING_STATUS, &status) &&
          !(status & FEED_READY)) {
        out.error = MapHr(kPaperEmpty);
        return;
      }
    }
    // Pick the child item for the chosen source (flatbed or feeder).
    ComPtr<IEnumWiaItem2> en;
    ComPtr<IWiaItem2> item;
    if (SUCCEEDED(root->EnumChildItems(nullptr, &en))) {
      ComPtr<IWiaItem2> child;
      ULONG n = 0;
      while (en->Next(1, &child, &n) == S_OK && n == 1) {
        ComPtr<IWiaPropertyStorage> ps;
        GUID cat = {};
        if (SUCCEEDED(child.As(&ps)) &&
            ReadGuid(ps.Get(), WIA_IPA_ITEM_CATEGORY, &cat)) {
          if ((feeder && cat == WIA_CATEGORY_FEEDER) ||
              (!feeder && cat == WIA_CATEGORY_FLATBED)) {
            item = child;
            break;
          }
          if (!item && cat != WIA_CATEGORY_FINISHED_FILE) item = child;
        }
        child.Reset();
      }
    }
    if (!item) {
      out.error = {"failed", "This scanner does not offer that source."};
      return;
    }
    ComPtr<IWiaPropertyStorage> ps;
    item.As(&ps);
    const LONG dpi = p.dpi;
    WriteLong(ps.Get(), WIA_IPS_XRES, dpi);
    WriteLong(ps.Get(), WIA_IPS_YRES, dpi);
    WriteLong(ps.Get(), WIA_IPA_DATATYPE,
              p.color_mode == "grayscale" ? WIA_DATA_GRAYSCALE
              : p.color_mode == "blackAndWhite" ? WIA_DATA_THRESHOLD
                                                : WIA_DATA_COLOR);
    WriteLong(ps.Get(), WIA_IPS_XPOS, 0);
    WriteLong(ps.Get(), WIA_IPS_YPOS, 0);
    WriteLong(ps.Get(), WIA_IPS_XEXTENT, (LONG)(p.width_mm / 25.4 * dpi));
    WriteLong(ps.Get(), WIA_IPS_YEXTENT, (LONG)(p.height_mm / 25.4 * dpi));
    if (feeder) {
      WriteLong(ps.Get(), WIA_IPS_DOCUMENT_HANDLING_SELECT,
                p.source == "duplex" ? (FEEDER | DUPLEX) : FEEDER);
      WriteLong(ps.Get(), WIA_IPS_PAGES, 0);  // 0 = every page in the feeder.
    }
    PROPSPEC fmt = {PRSPEC_PROPID};
    fmt.propid = WIA_IPA_FORMAT;
    PROPVARIANT v;
    PropVariantInit(&v);
    v.vt = VT_CLSID;
    GUID png = WiaImgFmt_PNG;
    v.puuid = &png;
    ps->WriteMultiple(1, &fmt, &v, WIA_IPA_FIRST);

    ComPtr<IWiaTransfer> transfer;
    if (FAILED(item.As(&transfer))) {
      out.error = {"failed", "This scanner cannot transfer images."};
      return;
    }
    ComPtr<Callback> cb;
    cb.Attach(new Callback(p.output_dir, progress));
    hr = transfer->Download(0, cb.Get());
    out.pages = cb->pages;
    if (hr == S_FALSE || g_cancel) {
      out.error = {"cancelled", "Scan cancelled."};
    } else if (FAILED(hr) && out.pages.empty()) {
      out.error = MapHr(hr);
    } else {
      // Running out of paper after at least one page is how a feeder ends.
      out.ok = !out.pages.empty();
      if (!out.ok) out.error = {"noPages", "The scanner returned no pages."};
    }
  }();
  if (SUCCEEDED(init)) CoUninitialize();
  return out;
}

}  // namespace evscan
