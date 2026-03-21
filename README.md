
## Proje Özeti

Pedestal, marina kullanıcılarının tekne başındaki **elektrik ve su istasyonlarını** uzaktan kontrol etmesine imkân tanır. Kullanıcılar abone kartlarıyla sisteme giriş yaparak istasyonlarını yönetebilir, bakiye işlemi gerçekleştirebilir ve tüketim raporlarına erişebilir.

---

## Temel Özellikler

| Özellik | Detay |
|---|---|
|  **Kimlik Doğrulama** | E-posta & şifre ile JWT tabanlı giriş; token iOS Keychain'de saklanır |
|  **İstasyon Kontrolü** | Elektrik ve su akışını tek dokunuşla aç / kapat |
|  **Bakiye Yönetimi** | Hesaba bakiye yükleme, istasyona bakiye aktarma ve iade |
|  **Tüketim Raporları** | Tarih aralığına göre su (L) ve elektrik (W) tüketim geçmişi |
|  **Kart Yönetimi** | Abone kartı listeleme ve sanal kart oluşturma |
|  **Simülasyon Modu** | Gerçek backend olmadan tam fonksiyonel test ortamı |

---

##  Teknoloji & Mimari

- **Dil:** Swift 5
- **UI:** SwiftUI
- **Mimari:** MVVM (Model–View–ViewModel)
- **Ağ:** `URLSession` + Swift Concurrency (`async/await`)
- **Güvenlik:** Keychain Services (JWT token yönetimi)
- **Platform:** iOS 16+

---

##  Proje Yapısı

```
mobileApp/
├── App/                  # Uygulama giriş noktası (MyApp.swift)
├── Core/
│   ├── Authentication/   # AuthViewModel, Keychain yardımcıları
│   ├── Network/          # ApiService – merkezi REST API istemcisi
│   └── Root/             # ContentView, navigasyon kökü
└── Features/
    ├── Auth/             # Giriş & kayıt ekranları
    ├── Home/             # Ana sayfa, QR tarayıcı, yan menü
    ├── Pedestals/        # İstasyon listesi ve detay & kontrol ekranı
    ├── Balance/          # Bakiye & kart yönetimi
    ├── History/          # Tüketim geçmişi
    ├── Profile/          # Kullanıcı profili
    └── Notification/     # Bildirim ekranı
```

---

##  API Entegrasyonu

REST tabanlı bir kurumsal backend ile `Bearer Token` kimlik doğrulama kullanılarak haberleşilmektedir. Başlıca endpoint'ler:

| İşlem | Endpoint |
|---|---|
| Giriş | `POST /api/Token/Authenticate` |
| Bakiye Sorgula | `GET /api/Customer/GetMevcutBakiye` |
| Bakiye Yükle | `POST /api/Customer/PostBakiyeYukle` |
| Aktif İstasyonlar | `GET /api/Customer/GetKullanilanPedestal` |
| İstasyon Bilgisi | `POST /api/Customer/PostIstasyonSonKayit` |
| Su / Elektrik Kontrol | `POST /api/Customer/PostElektrikSuAc` |
| Tüketim Raporu | `GET /api/Customer/GetKullaniciTuketimler` |

---

##  Lisans

Bu proje özel bir müşteri projesine aittir. Kaynak kod yalnızca portföy amaçlı paylaşılmaktadır.

---

<p align="center"><i>Bir marina işletmesi için sözleşmeli geliştirici olarak tasarlandı ve teslim edildi </i></p>
