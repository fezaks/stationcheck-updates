# stationcheck-updates

Uygulamaların internetten (OTA) güncelleme bilgisini ve paketlerini yayınladığı depo. Cihazlar yalnızca kendi
uygulamasının klasöründeki `surum.json` dosyasını okur; yeni sürüm varsa kendi platformunun paketini `zip_adres`'ten
indirir, `sha256` ile doğrular.

## Yapı

```
Data/<ProjeAdı>-<Uygulama ID>/     ← her uygulamanın kendi klasörü (ör. Data/StationCheck-101/)
    surum.json                     ← sürüm bilgisi (cihazlar bunu okur)
    Link.json                      ← uzak ayar paketi (cihaz henüz okumuyor; aşağıda)
    Win/paket.txt                  ← win-x64'ün son yayınının bilgisi (paketin kendisi release'te)
    Arm/paket.txt                  ← linux-arm'ın son yayınının bilgisi (paketin kendisi release'te)
    Log/yayinlar.txt               ← yayın geçmişi (her yayında bir satır)
yayinla.ps1                        ← ESKİ yapıya göre (101/, release); kullanılmıyor, yerine GitHubUpdater
README.md
```

StationCheck'in surum.json ham adresi (parametre 62):
`https://raw.githubusercontent.com/fezaks/stationcheck-updates/main/Data/StationCheck-101/surum.json`

| Uygulama ID | Uygulama |
|---|---|
| 101 | StationCheck |

Yeni bir uygulama eklenirken `Data/<ProjeAdı>-<Uygulama ID>/` klasörü açılır; diğer klasörlere dokunulmaz.
Paketler depoya **konmaz** (depo şişmesin): GitHub **release** `v<versiyon>`'a dosya olarak yüklenir (release dosya
sınırı 2 GB). Ad benzersizdir (önbellek yüzünden): `<id>_<versiyon>_<win|arm>_<yyyyMMdd-HHmmss>.<zip|rar>`. Aynı sürüm
yeniden yayınlanınca eski dosya release'te kalabilir; `surum.json` her zaman en yenisini gösterir. `Win/` ve `Arm/`
klasörlerinde yalnızca `paket.txt` durur (sürüm, paket adı, boyut, sha256, release adresi, yayın tarihi; her yayında
güncellenir).

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
| `paketler.<platform>.zip_adres` | metin | O platformun paketinin indirme adresi: release dosyası (ör. `https://github.com/fezaks/stationcheck-updates/releases/download/v101.26.45/101_101.26.45_arm_20261009-153000.zip`). Boşsa o platform için paket yok: o platformdaki cihaz güncelleme algılamaz. |
| `paketler.<platform>.sha256` | metin | Paketin SHA-256 özeti (küçük harf, onaltılık). İndirilen dosya bununla doğrulanır; uymazsa uygulanmaz. |

`versiyon` değeri `101.26.0` iken (ve paket adresleri boşken) hiçbir cihaz güncelleme algılamaz: başlangıç durumudur.

## Yayınlama (GitHubUpdater)

`C:\DATA\CLAUDE\GitHubUpdater` (Uygulama ID 1): uygulama ve platform seçilir, paket hazırlık klasörüne konur, sürüm
girilir, YAYINLA. Sırayla: paket (tek .zip / .rar olduğu gibi, değilse zip; benzersiz ad) → SHA-256 → release
`v<versiyon>` (yoksa açılır) dosyası olarak yüklenir → `surum.json`'da `versiyon` ve yalnızca o platformun
`zip_adres` + `sha256`'sı → `<Win|Arm>/paket.txt` → `Log/yayinlar.txt`'ye satır
(`tarih-saat | uygulama | platform | sürüm | paket adı | sha256`) → tek commit (`<id> <versiyon> (<platform>) yayınlandı`)
+ push. Commit'ten önce hata olursa yerel değişiklikler geri alınır. Sunucudakiyle **aynı** sürüm onayla yeniden
yayınlanabilir (cihazlar otomatik çekmez; yalnız manuel "yeniden yükle" ile alınır); **küçük** sürüm yayınlanamaz.

## Link.json (uzak ayar paketi; cihaz henüz okumuyor)

| Alan | Tür | Anlamı |
|---|---|---|
| `aciklama` | metin | İnsan için açıklama. |
| `surum` | sayı | Bu dosyanın kendi biçim / içerik sürümü (değişince artırılır). |
| `guncelleme_adresleri` | metin dizisi | Cihazın sırayla deneyeceği `surum.json` adresleri (ilki asıl, diğerleri yedek). |
| `rapor_host_url` | metin | Cihazların durum raporu göndereceği sunucu adresi; boş = rapor yok. |

## Eski betik (yayinla.ps1; eski yapıya göre, kullanılmıyor)

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
