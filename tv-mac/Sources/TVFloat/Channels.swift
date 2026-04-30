import Foundation

struct Channel: Identifiable, Codable {
    var id       = UUID()
    var name:      String
    var url:       String
    var useZDFApi: Bool = false

    init(name: String, url: String, useZDFApi: Bool = false) {
        self.name      = name
        self.url       = url
        self.useZDFApi = useZDFApi
    }
}

// Standard-Senderliste – wird als Fallback genutzt wenn noch keine
// gespeicherte Konfiguration vorhanden ist.
let defaultChannels: [Channel] = [
    Channel(name: "Das Erste",         url: "https://daserste-live.ard-mcdn.de/daserste/live/hls/de/master.m3u8"),
    Channel(name: "ZDF",               url: "https://zdf-hls-18.akamaized.net/hls/live/2016501/de/high/master.m3u8", useZDFApi: true),
    Channel(name: "RBB Berlin",        url: "https://rbb-hls-berlin.akamaized.net/hls/live/2017824/rbb_berlin/master.m3u8"),
    Channel(name: "Arte",              url: "https://artesimulcast.akamaized.net/hls/live/2030993/artelive_de/index.m3u8"),
    Channel(name: "One",               url: "https://mcdn-one.ard.de/ardone/hls/master.m3u8"),
    Channel(name: "Welt",              url: "https://w-live2weltcms.akamaized.net/hls/live/2041019/Welt-LivePGM/index.m3u8"),
    Channel(name: "ZDFneo",            url: "https://zdf-hls-16.akamaized.net/hls/live/2016499/de/veryhigh/master.m3u8"),
    Channel(name: "ZDFinfo",           url: "https://zdf-hls-17.akamaized.net/hls/live/2016500/de/veryhigh/master.m3u8"),
    Channel(name: "WDR",               url: "https://wdrfs247.akamaized.net/hls/live/681509/wdr_msl4_fs247/index.m3u8"),
    Channel(name: "Phoenix",           url: "https://zdf-hls-19.akamaized.net/hls/live/2016502/de/veryhigh/master.m3u8"),
    Channel(name: "3sat",              url: "https://zdf-hls-18.akamaized.net/hls/live/2016501/dach/veryhigh/master.m3u8"),
    Channel(name: "ARD Alpha",         url: "https://mcdn.br.de/br/fs/ard_alpha/hls/de/master.m3u8"),
    Channel(name: "KiKA",              url: "https://kikageohls.akamaized.net/hls/live/2022693/livetvkika_de/master.m3u8"),
    Channel(name: "Tagesschau24",      url: "https://tagesschau.akamaized.net/hls/live/2020115/tagesschau/tagesschau_1/master.m3u8"),
    Channel(name: "BR Fernsehen",      url: "https://brcdn.vo.llnwd.net/br/fs/bfs_sued/hls/de/master.m3u8"),
    Channel(name: "HR Fernsehen",      url: "https://hrhls.akamaized.net/hls/live/2024525/hrhls/master.m3u8"),
    Channel(name: "MDR Sachsen",       url: "https://mdrtvsnhls.akamaized.net/hls/live/2016928/mdrtvsn/master.m3u8"),
    Channel(name: "NDR NDS",           url: "https://mcdn.ndr.de/ndr/hls/ndr_fs/ndr_nds/master.m3u8"),
    Channel(name: "Radio Bremen TV",   url: "https://rbhlslive.akamaized.net/hls/live/2020435/rbfs/master.m3u8"),
    Channel(name: "SR Fernsehen",      url: "https://srfs.akamaized.net/hls/live/689649/srfsgeo/index.m3u8"),
    Channel(name: "SWR BW",            url: "https://swrbwd-hls.akamaized.net/hls/live/2018672/swrbwd/master.m3u8"),
    Channel(name: "NDR International", url: "https://ndrint.akamaized.net/hls/live/2020766/ndr_int/index.m3u8"),
    Channel(name: "Deluxe Music",      url: "https://sdn-global-live-streaming-packager-cache.3qsdn.com/13456/13456_264_live.m3u8"),
    Channel(name: "Deluxe Dance",      url: "https://sdn-global-live-streaming-packager-cache.3qsdn.com/64733/64733_264_live.m3u8"),
    Channel(name: "Deluxe Rap",        url: "https://sdn-global-live-streaming-packager-cache.3qsdn.com/65183/65183_264_live.m3u8"),
    Channel(name: "Schlager Deluxe",   url: "https://sdn-global-live-streaming-packager-cache.3qsdn.com/26658/26658_264_live.m3u8"),
]
