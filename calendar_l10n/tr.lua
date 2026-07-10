-- calendar_l10n/tr.lua — Turkish. Keys must match the English source exactly.
return {
    -- Menu / actions
    ["Calendar"] = "Takvim",
    ["Open viewer"] = "Görüntüleyiciyi aç",
    ["Refresh now"] = "Şimdi yenile",
    ["Calendars"] = "Takvimler",
    ["Open calendar"] = "Takvimi aç",
    ["Refresh calendar"] = "Takvimi yenile",
    ["Sleep-screen mode: %1"] = "Uyku ekranı modu: %1",
    ["Week starts on: %1"] = "Hafta başlangıcı: %1",
    ["Refresh interval"] = "Yenileme aralığı",
    ["Refresh interval (hours)"] = "Yenileme aralığı (saat)",
    ["On sleep, refetch calendars whose cache is older than this."]
        = "Uykuya geçerken, önbelleği bundan eski olan takvimleri yeniden indir.",
    ["Turn on Wi-Fi on sleep if outdated"] = "Güncel değilse uykuda Wi-Fi'ı aç",
    ["When entering sleep with Wi-Fi off and a calendar cache older than the threshold below, briefly turn Wi-Fi on to refresh, then turn it off again. Can delay entering sleep and uses some battery."]
        = "Wi-Fi kapalıyken uykuya geçilirken takvim önbelleği aşağıdaki eşikten eskiyse Wi-Fi kısa süreliğine açılır, yenileme yapılır ve tekrar kapatılır. Uykuya geçişi geciktirebilir ve bir miktar pil kullanır.",
    ["Wi-Fi refresh threshold: %1 h"] = "Wi-Fi yenileme eşiği: %1 sa",
    ["Wi-Fi refresh threshold (hours)"] = "Wi-Fi yenileme eşiği (saat)",
    ["On sleep with Wi-Fi off, turn it on and refresh only when the calendar cache is older than this. Wi-Fi is turned off again afterwards."]
        = "Wi-Fi kapalıyken uykuya geçildiğinde, yalnızca takvim önbelleği bundan eskiyse Wi-Fi açılıp yenileme yapılır. Sonrasında Wi-Fi yeniden kapatılır.",
    ["Monday"] = "Pazartesi",
    ["Sunday"] = "Pazar",

    -- Refresh feedback
    ["Refreshing calendars…"] = "Takvimler yenileniyor…",
    ["Calendar refreshed."] = "Takvim yenilendi.",
    ["Could not refresh calendar."] = "Takvim yenilenemedi.",

    -- Configuration
    ["Reload configuration"] = "Yapılandırmayı yeniden yükle",
    ["Create configuration file from sample"] = "Örnekten yapılandırma dosyası oluştur",
    ["Show configuration file path"] = "Yapılandırma dosyası yolunu göster",
    ["Configuration file already exists."] = "Yapılandırma dosyası zaten var.",
    ["Sample configuration not found."] = "Örnek yapılandırma bulunamadı.",
    ["Could not write configuration file."] = "Yapılandırma dosyası yazılamadı.",
    ["Configuration reloaded. %1 calendar(s) enabled/listed."]
        = "Yapılandırma yeniden yüklendi. %1 takvim listelendi.",
    ["No configuration - tap for help"] = "Yapılandırma yok - yardım için dokunun",
    ["Configuration error - tap for details"] = "Yapılandırma hatası - ayrıntılar için dokunun",
    ["Configuration error:\n%1"] = "Yapılandırma hatası:\n%1",
    ["(no calendars in configuration)"] = "(yapılandırmada takvim yok)",
    ["Created:\n%1\n\nEdit it (paste your calendar URL), then Reload configuration."]
        = "Oluşturuldu:\n%1\n\nDüzenleyin (takvim URL'nizi yapıştırın), sonra \"Yapılandırmayı yeniden yükle\"yi kullanın.",
    [ [[No calendar configuration found.

To add your Google Calendar(s):
1. Copy this file:
%1
   to (remove ".sample"):
%2
2. Edit it and paste your calendar's "Secret address in iCal format" URL
   (Google Calendar → Settings → your calendar → Integrate calendar).
   Editing on a computer is easiest.
3. Then use "Reload configuration".

You can also tap "Create configuration file from sample" to create the file now.]] ]
        = [[Takvim yapılandırması bulunamadı.

Google Takvim(ler)inizi eklemek için:
1. Şu dosyayı kopyalayın:
%1
   şuraya (".sample" kısmını kaldırın):
%2
2. Dosyayı düzenleyip takviminizin "iCal biçiminde gizli adres" URL'sini yapıştırın
   (Google Takvim → Ayarlar → takviminiz → Takvimi entegre et).
   Bilgisayarda düzenlemek en kolayıdır.
3. Ardından "Yapılandırmayı yeniden yükle"yi kullanın.

Dosyayı şimdi oluşturmak için "Örnekten yapılandırma dosyası oluştur"a da dokunabilirsiniz.]],

    -- Viewer
    ["Day"] = "Gün",
    ["Week"] = "Hafta",
    ["Month"] = "Ay",
    ["Agenda"] = "Ajanda",
    ["Today"] = "Bugün",
    ["Sync"] = "Eşitle",
    ["Event"] = "Etkinlik",
    ["Events"] = "Etkinlikler",
    ["No events"] = "Etkinlik yok",
    ["All day"] = "Tüm gün",
    ["Location: "] = "Konum: ",
    ["Calendar: "] = "Takvim: ",
    ["Last synced %1"] = "Son eşitleme: %1",
    ["+%1 more"] = "+%1 daha",
    ["Agenda from %1"] = "Ajanda başlangıcı: %1",

    -- Sleep screen
    ["Show calendar on sleep screen"] = "Uyku ekranında takvimi göster",
    ["Calendar view mode: "] = "Takvim görünüm modu: ",
}
