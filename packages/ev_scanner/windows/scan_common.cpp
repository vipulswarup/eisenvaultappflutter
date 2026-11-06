#include "scan_core.h"

#include <windows.h>
#include <shlwapi.h>
#include <wincodec.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

namespace evscan {

std::atomic<bool> g_cancel{false};

std::string Utf8(const std::wstring& w) {
  if (w.empty()) return {};
  int n = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), nullptr, 0,
                              nullptr, nullptr);
  std::string s(n, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), s.data(), n, nullptr,
                      nullptr);
  return s;
}

std::wstring Wide(const std::string& s) {
  if (s.empty()) return {};
  int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring w(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), w.data(), n);
  return w;
}

bool SaveDibAsPng(const void* dib, size_t dib_size, const std::wstring& path) {
  if (dib_size < sizeof(BITMAPINFOHEADER)) return false;
  const BITMAPINFOHEADER* h = static_cast<const BITMAPINFOHEADER*>(dib);
  DWORD colors = h->biClrUsed;
  if (colors == 0 && h->biBitCount <= 8) colors = 1u << h->biBitCount;
  DWORD masks = (h->biCompression == BI_BITFIELDS && h->biSize == 40) ? 12 : 0;
  BITMAPFILEHEADER fh = {};
  fh.bfType = 0x4D42;
  fh.bfOffBits = sizeof(fh) + h->biSize + masks + colors * sizeof(RGBQUAD);
  fh.bfSize = (DWORD)(sizeof(fh) + dib_size);

  std::vector<BYTE> bmp(sizeof(fh) + dib_size);
  memcpy(bmp.data(), &fh, sizeof(fh));
  memcpy(bmp.data() + sizeof(fh), dib, dib_size);

  HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  bool ok = false;
  {
    ComPtr<IStream> in(SHCreateMemStream(bmp.data(), (UINT)bmp.size()));
    ComPtr<IWICImagingFactory> factory;
    ComPtr<IWICBitmapDecoder> decoder;
    ComPtr<IWICBitmapFrameDecode> frame;
    ComPtr<IWICStream> out;
    ComPtr<IWICBitmapEncoder> encoder;
    ComPtr<IWICBitmapFrameEncode> enc_frame;
    ComPtr<IPropertyBag2> props;
    if (in &&
        SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                   CLSCTX_INPROC_SERVER,
                                   IID_PPV_ARGS(&factory))) &&
        SUCCEEDED(factory->CreateDecoderFromStream(
            in.Get(), nullptr, WICDecodeMetadataCacheOnDemand, &decoder)) &&
        SUCCEEDED(decoder->GetFrame(0, &frame)) &&
        SUCCEEDED(factory->CreateStream(&out)) &&
        SUCCEEDED(out->InitializeFromFilename(path.c_str(), GENERIC_WRITE)) &&
        SUCCEEDED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                         &encoder)) &&
        SUCCEEDED(encoder->Initialize(out.Get(), WICBitmapEncoderNoCache)) &&
        SUCCEEDED(encoder->CreateNewFrame(&enc_frame, &props)) &&
        SUCCEEDED(enc_frame->Initialize(props.Get()))) {
      UINT w = 0, ht = 0;
      frame->GetSize(&w, &ht);
      double dx = 0, dy = 0;
      frame->GetResolution(&dx, &dy);
      enc_frame->SetSize(w, ht);
      if (dx > 0 && dy > 0) enc_frame->SetResolution(dx, dy);
      WICPixelFormatGUID fmt;
      frame->GetPixelFormat(&fmt);
      WICPixelFormatGUID want = fmt;
      enc_frame->SetPixelFormat(&want);
      ComPtr<IWICBitmapSource> src = frame;
      ComPtr<IWICFormatConverter> conv;
      if (!IsEqualGUID(want, fmt) &&
          SUCCEEDED(factory->CreateFormatConverter(&conv)) &&
          SUCCEEDED(conv->Initialize(frame.Get(), want,
                                     WICBitmapDitherTypeNone, nullptr, 0.0,
                                     WICBitmapPaletteTypeCustom))) {
        src = conv;
      }
      ok = SUCCEEDED(enc_frame->WriteSource(src.Get(), nullptr)) &&
           SUCCEEDED(enc_frame->Commit()) && SUCCEEDED(encoder->Commit());
    }
  }
  if (SUCCEEDED(init)) CoUninitialize();
  if (!ok) DeleteFileW(path.c_str());
  return ok;
}

}  // namespace evscan
