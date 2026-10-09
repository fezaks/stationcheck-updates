# stationcheck-updates

Uygulamaların internetten (OTA) güncelleme bilgisini yayınladığı depo. Cihazlar yalnızca kendi Uygulama ID
klasöründeki `surum.json` dosyasını okur; yeni sürüm varsa kendi platformunun paketini `zip_adres`'ten indirir,
`sha256` ile doğrular.

## Yapı

```
<Uygulama ID>/surum.json     ← her uygulamanın kendi klasörü (101, 102, 103 …)
yayinla.ps1                  ← paketi zip'leyip release'e yükleyen, surum.json'u güncelleyen betik
README.md
```

| Uygulama ID | Uygulama |
|---|---|
| 101 | StationCheck |

Yeni bir uygulama eklenirken kendi Uygulama ID'siyle yeni bir klasör açılır; diğer klasörlere dokunulmaz.
Paketler (zip) depoya değil, GitHub **release**'lerine dosya olarak yüklenir (etiket: `v<versiyon>`).

## surum.json

```json
{
  "uygulama_id": "101",
  "versiyon": "101.26.0",
  "zorunlu": false,
  "paketler": {
    "win-x64": { "zip_adres": "", "sha256": "" },
    "linux-arm": { "zip_adres": "", "sha256": "" }
  }
}
```

| Alan | Tür | Anlamı |
|---|---|---|
| `uygulama_id` | metin | Uygulama ID (klasör adıyla aynı, ör. `"101"`). Cihaz kendi ID'siyle eşleşmeyen dosyayı yok sayar. |
| `versiyon` | metin | Yayındaki sürümün birleşik kodu: `<Uygulama ID>.<yy>.<derleme>` (ör. `"101.26.45"`). Parçalar sayı olarak karşılaştırılır (101.26.100 > 101.26.45); cihaz yalnızca kendi sürümünden büyükse güncelleme var sayar. |
| `zorunlu` | mantıksal | `true`: güncelleme zorunlu; `false`: isteğe bağlı. |
| `paketler` | nesne | Platforma göre paketler. Anahtar platform adıdır: `win-x64` (Windows), `linux-arm` (Orange Pi, 32-bit ARM). |
| `paketler.<platform>.zip_adres` | metin | O platformun paketinin (zip) indirme adresi (release dosyası). Boşsa o platform için paket yok: o platformdaki cihaz güncelleme algılamaz. |
| `paketler.<platform>.sha256` | metin | Paketin SHA-256 özeti (küçük harf, onaltılık). İndirilen dosya bununla doğrulanır; uymazsa uygulanmaz. |

`versiyon` değeri `101.26.0` iken (ve paket adresleri boşken) hiçbir cihaz güncelleme algılamaz: başlangıç durumudur.

## Yayınlama (yayinla.ps1)

```powershell
powershell -ExecutionPolicy Bypass -File yayinla.ps1 -UygulamaID 101 -Versiyon 101.26.45 -Platform linux-arm -Klasor C:\DATA\CLAUDE\StationCheck\ReleaseArm\StationCheck
```

Sırayla: klasörü zip'ler (`<UygulamaID>_<Versiyon>_<Platform>.zip`; `Data`, `Sys`, `Log` klasörleri pakete girmez),
SHA-256'sını hesaplar, `v<Versiyon>` release'i yoksa açar ve zip'i yükler (aynı adda dosya varsa değiştirir), ancak
yükleme başarılıysa `<UygulamaID>/surum.json`'da `versiyon`'u ve yalnızca o platformun `zip_adres` + `sha256`
alanlarını günceller (öbür platforma dokunmaz), commit + push eder, tek satır özet yazar. Herhangi bir adım başarısız
olursa `surum.json`'a dokunmadan durur. `-Deneme`: "deneme" etiketli ön-sürüm (prerelease) açar, zip'i yükler,
`surum.json`'a dokunmaz (betiği denemek için).

Önbellek: ham adres (`raw.githubusercontent.com`) `Cache-Control: max-age=300` döndürür; `surum.json` değişikliği
cihaza en geç yaklaşık 5 dakikada ulaşır.
