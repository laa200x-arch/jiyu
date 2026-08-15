import SwiftUI
import MapKit
import CoreLocation

/// 同城地图（方案 2.3.3 线下交换）
/// 使用 iOS 内建 MapKit（无需第三方地图 Key）：
/// - 展示匹配用户的同城位置（按区定位 + 随机微偏移，避免同区重叠）
/// - 用户定位权限开启时以真实位置为中心
/// - 正式版可替换为高德地图 SDK + 服务器存储经纬度
struct MatchMapView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationProvider = LocationProvider.shared

    let results: [SkillMatchResult]

    @State private var region: MKCoordinateRegion
    @State private var selectedPin: MapPin?

    struct MapPin: Identifiable {
        let id: UUID
        let name: String
        let distanceKm: Double?
        let coordinate: CLLocationCoordinate2D
        let isVip: Bool
        let result: SkillMatchResult
    }

    init(results: [SkillMatchResult]) {
        self.results = results
        _region = State(initialValue: MKCoordinateRegion(
            center: Self.districtCenters["海淀"]!,
            span: MKCoordinateSpan(latitudeDelta: 0.7, longitudeDelta: 0.7)
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(coordinateRegion: $region, annotationItems: pins) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: pin.isVip ? Theme.secondary : Theme.primary)
                }
                .frame(height: 380)
                .overlay(alignment: .topLeading) {
                    Text("匹配用户同城分布 · 位置为区级示意")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.cardBg.opacity(0.9)))
                        .padding(10)
                }

                if let selectedPin {
                    selectedCard(selectedPin)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pins) { pin in
                            pinChip(pin)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 90)
            }
            .background(Theme.bg)
            .navigationTitle("同城地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                centerOnUser()
            }
            .onChange(of: locationProvider.location) { _ in
                centerOnUser()
            }
        }
    }

    // MARK: - 数据

    private var pins: [MapPin] {
        results.compactMap { result in
            guard let coordinate = Self.coordinate(for: result.user.locationLabel) else { return nil }
            return MapPin(
                id: result.user.id,
                name: result.user.userName,
                distanceKm: result.user.distanceKm,
                coordinate: coordinate,
                isVip: result.user.isExposureVip,
                result: result
            )
        }
    }

    private func centerOnUser() {
        if let location = locationProvider.location {
            withAnimation(.easeInOut(duration: 0.4)) {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            }
        }
    }

    private func select(_ pin: MapPin) {
        selectedPin = pin
        withAnimation(.easeInOut(duration: 0.4)) {
            region = MKCoordinateRegion(
                center: pin.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        }
    }

    // MARK: - 视图

    private func pinChip(_ pin: MapPin) -> some View {
        Button {
            select(pin)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(pin.isVip
                              ? AnyShapeStyle(Theme.secondary)
                              : AnyShapeStyle(Theme.gradient))
                        .frame(width: 40, height: 40)
                    Image(systemName: pin.result.user.avatarSymbol)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                Text(pin.name)
                    .font(.caption)
                    .foregroundStyle(Theme.textPrimary)
                if let distance = pin.distanceKm {
                    Text(String(format: "%.1f km", distance))
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 72)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(
                selectedPin?.id == pin.id ? Theme.primary.opacity(0.15) : Theme.cardBg
            ))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                selectedPin?.id == pin.id ? Theme.primary : Theme.divider, lineWidth: 1
            ))
        }
        .buttonStyle(.plain)
    }

    private func selectedCard(_ pin: MapPin) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(pin.isVip
                          ? AnyShapeStyle(Theme.secondary)
                          : AnyShapeStyle(Theme.gradient))
                    .frame(width: 44, height: 44)
                Image(systemName: pin.result.user.avatarSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pin.name)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Theme.textPrimary)
                    if pin.isVip {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.secondary)
                    }
                    if let distance = pin.distanceKm {
                        Text("· \(String(format: "%.1f", distance)) km")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Text("你教：\(pin.result.mySkillsForThem.joined(separator: "、"))｜TA教你：\(pin.result.theirSkillsForMe.joined(separator: "、"))")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            NavigationLink {
                MatchDetailView(result: pin.result)
            } label: {
                Text("查看")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.primary))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.divider, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    // MARK: - 区级定位（正式版替换为服务器经纬度 + 高德 SDK）

    private static let districtCenters: [String: CLLocationCoordinate2D] = [
        "海淀": CLLocationCoordinate2D(latitude: 39.9603, longitude: 116.2981),
        "朝阳": CLLocationCoordinate2D(latitude: 39.9215, longitude: 116.4431),
        "西城": CLLocationCoordinate2D(latitude: 39.9153, longitude: 116.3660),
        "东城": CLLocationCoordinate2D(latitude: 39.9175, longitude: 116.4188),
        "丰台": CLLocationCoordinate2D(latitude: 39.8584, longitude: 116.2870),
        "通州": CLLocationCoordinate2D(latitude: 39.9097, longitude: 116.6570),
        "昌平": CLLocationCoordinate2D(latitude: 40.2208, longitude: 116.2312),
        "大兴": CLLocationCoordinate2D(latitude: 39.7269, longitude: 116.3415)
    ]

    private static func coordinate(for label: String) -> CLLocationCoordinate2D? {
        guard let key = districtCenters.keys.first(where: { label.contains($0) }) else { return nil }
        var coordinate = districtCenters[key]!
        // 同区用户加微小随机偏移，避免标记完全重叠
        let hash = abs(label.hashValue)
        coordinate.latitude += Double(hash % 50) / 1000.0
        coordinate.longitude += Double((hash / 50) % 50) / 1000.0
        return coordinate
    }
}

/// 定位提供者（同城地图使用；拒绝授权时回退区级示意位置）
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
}
