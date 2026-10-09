# stationcheck-updates

Uygulamaların internetten (OTA) güncelleme bilgisini yayınladığı depo. Cihazlar yalnızca kendi Uygulama ID
klasöründeki `surum.json` dosyasını okur; yeni sürüm varsa paketi `zip_adres`'ten indirir, `sha256` ile doğrular.

## Yapı

```
<Uygulama ID>/surum.json     ← her uygulamanın kendi klasörü (101, 102, 103 …)
README.md
```

| Uygulama ID | Uygulama |
|---|---|
| 101 | StationCheck |

Yeni bir uygulama eklenirken kendi Uygulama ID'siyle yeni bir klasör açılır; diğer klasörlere dokunulmaz.

## surum.json alanları

| Alan | Tür | Anlamı |
|---|---|---|
| `uygulama_id` | metin | Uygulama ID (klasör adıyla aynı, ör. `"101"`). Cihaz kendi ID'siyle eşleşmeyen dosyayı yok sayar. |
| `versiyon` | metin | Yayındaki sürümün birleşik kodu: `<Uygulama ID>.<yy>.<derleme>` (ör. `"101.26.35"`). Cihaz yalnızca kendi sürümünden büyükse güncelleme var sayar. |
| `zip_adres` | metin | Güncelleme paketinin (zip) indirme adresi. Boşsa indirilecek paket yok. |
| `sha256` | metin | Paketin SHA-256 özeti (küçük harf, onaltılık). İndirilen dosya bununla doğrulanır; uymazsa uygulanmaz. |
| `zorunlu` | mantıksal | `true`: güncelleme zorunlu; `false`: isteğe bağlı. |

`versiyon` değeri `101.26.0` iken (ve `zip_adres` boşken) hiçbir cihaz güncelleme algılamaz: başlangıç durumudur.
