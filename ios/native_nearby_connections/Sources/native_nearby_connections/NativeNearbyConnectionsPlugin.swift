import Flutter
import Foundation
import NearbyConnections

/// Bridges Google Nearby Connections (Swift) to Dart via Pigeon.
///
/// The Swift SDK differs from Android: strategy and service ID are fixed per
/// `ConnectionManager`, and accept/reject happen through handler closures instead of
/// methods. This class maps those onto the Android-shaped Pigeon API:
/// - incoming requests are let through the advertiser's first gate; the verification
///   step becomes `onConnectionInitiated`, answered by `acceptConnection`/`rejectConnection`.
/// - connection state changes become `onConnectionResult` (Android status codes) or
///   `onDisconnected`.
@MainActor
public class NativeNearbyConnectionsPlugin: NSObject {
  // Android `ConnectionsStatusCodes`, so Dart sees the same values on both platforms.
  private static let statusOK: Int64 = 0
  private static let statusError: Int64 = 13
  private static let statusRejected: Int64 = 8004

  private let flutterApi: NearbyFlutterApi
  private var advertiser: Advertiser?
  private var discoverer: Discoverer?
  /// The SDK only holds these weakly, and they relay callbacks for connections they
  /// made, so they stay alive after stopping until `stopAllEndpoints`.
  /// shortcut: grows by one per start call until stopAllEndpoints; prune per endpoint if apps restart often.
  private var keepAlive: [AnyObject] = []
  /// Manager each endpoint belongs to; payloads must go through it to get transfer updates.
  private var managers: [String: ConnectionManager] = [:]
  private var names: [String: String] = [:]
  private var incoming: Set<String> = []
  private var verifications: [String: (Bool) -> Void] = [:]
  private var connected: Set<String> = []
  private var tokens: [Int64: CancellationToken] = [:]

  init(flutterApi: NearbyFlutterApi) {
    self.flutterApi = flutterApi
  }

  private func emit(_ call: @escaping @MainActor (NearbyFlutterApi) async throws -> Void) {
    // A missing Dart listener must not crash native callbacks.
    Task { @MainActor in try? await call(flutterApi) }
  }

  private func forget(_ endpointId: String) {
    managers[endpointId] = nil
    names[endpointId] = nil
    incoming.remove(endpointId)
    verifications[endpointId] = nil
    connected.remove(endpointId)
  }

  private static func complete(_ start: (@escaping (Error?) -> Void) -> Void) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      start { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
  }

  private static func strategy(_ strategy: NearbyStrategy) -> Strategy {
    switch strategy {
    case .cluster: return .cluster
    case .star: return .star
    case .pointToPoint: return .pointToPoint
    }
  }

  /// Sends one payload id to endpoints that may belong to different managers.
  private func send(
    to endpointIds: [String],
    _ send: (ConnectionManager, [String], PayloadID) -> (@escaping (Error?) -> Void) -> CancellationToken
  ) async throws -> Int64 {
    let id = PayloadID.unique()
    var groups: [ObjectIdentifier: (ConnectionManager, [String])] = [:]
    for endpointId in endpointIds {
      guard let manager = managers[endpointId] else {
        throw PigeonError(code: "UNKNOWN_ENDPOINT", message: "Not connected to \(endpointId)", details: nil)
      }
      groups[ObjectIdentifier(manager), default: (manager, [])].1.append(endpointId)
    }
    for (manager, ids) in groups.values {
      try await Self.complete { done in tokens[id] = send(manager, ids, id)(done) }
    }
    return id
  }
}

extension NativeNearbyConnectionsPlugin: @preconcurrency FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let instance = NativeNearbyConnectionsPlugin(flutterApi: NearbyFlutterApi(binaryMessenger: messenger))
    NearbyHostApiSetup.setUp(binaryMessenger: messenger, api: instance)
    registrar.publish(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    NearbyHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    try? stopAllEndpoints()
  }
}

extension NativeNearbyConnectionsPlugin: @preconcurrency NearbyHostApi {
  func startAdvertising(name: String, serviceId: String, strategy: NearbyStrategy) async throws {
    // A session left over from before a Dart hot restart would fail the start as already advertising.
    try stopAdvertising()
    let manager = ConnectionManager(serviceID: serviceId, strategy: Self.strategy(strategy))
    manager.delegate = self
    let advertiser = Advertiser(connectionManager: manager)
    advertiser.delegate = self
    keepAlive.append(advertiser)
    self.advertiser = advertiser
    try await Self.complete { advertiser.startAdvertising(using: Data(name.utf8), completionHandler: $0) }
  }

  func startDiscovery(serviceId: String, strategy: NearbyStrategy) async throws {
    // A session left over from before a Dart hot restart would fail the start as already discovering.
    try stopDiscovery()
    let manager = ConnectionManager(serviceID: serviceId, strategy: Self.strategy(strategy))
    manager.delegate = self
    let discoverer = Discoverer(connectionManager: manager)
    discoverer.delegate = self
    keepAlive.append(discoverer)
    self.discoverer = discoverer
    try await Self.complete { discoverer.startDiscovery(completionHandler: $0) }
  }

  func requestConnection(name: String, endpointId: String) async throws {
    guard let discoverer, managers[endpointId] === discoverer.connectionManager else {
      throw PigeonError(
        code: "UNKNOWN_ENDPOINT", message: "\(endpointId) was not found by the current discovery",
        details: nil)
    }
    try await Self.complete {
      discoverer.requestConnection(to: endpointId, using: Data(name.utf8), completionHandler: $0)
    }
  }

  func acceptConnection(endpointId: String) async throws {
    guard let verify = verifications.removeValue(forKey: endpointId) else {
      throw PigeonError(code: "NO_PENDING_CONNECTION", message: "No connection initiated with \(endpointId)", details: nil)
    }
    verify(true)
  }

  func rejectConnection(endpointId: String) async throws {
    guard let verify = verifications.removeValue(forKey: endpointId) else {
      throw PigeonError(code: "NO_PENDING_CONNECTION", message: "No connection initiated with \(endpointId)", details: nil)
    }
    verify(false)
  }

  func sendBytes(endpointIds: [String], bytes: FlutterStandardTypedData) async throws -> Int64 {
    try await send(to: endpointIds) { manager, ids, id in
      { manager.send(bytes.data, to: ids, id: id, completionHandler: $0) }
    }
  }

  func sendFile(endpointIds: [String], path: String) async throws -> Int64 {
    let url = URL(fileURLWithPath: path)
    return try await send(to: endpointIds) { manager, ids, id in
      { manager.sendResource(at: url, withName: url.lastPathComponent, to: ids, id: id, completionHandler: $0) }
    }
  }

  func cancelPayload(payloadId: Int64) throws {
    tokens.removeValue(forKey: payloadId)?.cancel()
  }

  func stopAdvertising() throws {
    advertiser?.stopAdvertising()
    advertiser = nil
  }

  func stopDiscovery() throws {
    discoverer?.stopDiscovery()
    discoverer = nil
  }

  func disconnect(endpointId: String) throws {
    managers[endpointId]?.disconnect(from: endpointId)
    forget(endpointId)
  }

  func stopAllEndpoints() throws {
    try stopAdvertising()
    try stopDiscovery()
    for endpointId in connected { managers[endpointId]?.disconnect(from: endpointId) }
    managers = [:]
    names = [:]
    incoming = []
    verifications = [:]
    connected = []
    tokens = [:]
    keepAlive = []
  }
}

extension NativeNearbyConnectionsPlugin: @preconcurrency DiscovererDelegate {
  public func discoverer(_ discoverer: Discoverer, didFind endpointID: EndpointID, with context: Data) {
    let name = String(decoding: context, as: UTF8.self)
    managers[endpointID] = discoverer.connectionManager
    names[endpointID] = name
    let info = EndpointInfo(endpointId: endpointID, name: name, serviceId: discoverer.connectionManager.serviceID)
    emit { try await $0.onEndpointFound(info: info) }
  }

  public func discoverer(_ discoverer: Discoverer, didLose endpointID: EndpointID) {
    if !connected.contains(endpointID) && verifications[endpointID] == nil { forget(endpointID) }
    emit { try await $0.onEndpointLost(endpointId: endpointID) }
  }
}

extension NativeNearbyConnectionsPlugin: @preconcurrency AdvertiserDelegate {
  public func advertiser(
    _ advertiser: Advertiser, didReceiveConnectionRequestFrom endpointID: EndpointID,
    with context: Data, connectionRequestHandler: @escaping (Bool) -> Void
  ) {
    managers[endpointID] = advertiser.connectionManager
    names[endpointID] = String(decoding: context, as: UTF8.self)
    incoming.insert(endpointID)
    // Dart decides at the verification step, which carries the auth digits.
    connectionRequestHandler(true)
  }
}

extension NativeNearbyConnectionsPlugin: @preconcurrency ConnectionManagerDelegate {
  public func connectionManager(
    _ connectionManager: ConnectionManager, didReceive verificationCode: String,
    from endpointID: EndpointID, verificationHandler: @escaping (Bool) -> Void
  ) {
    managers[endpointID] = connectionManager
    verifications[endpointID] = verificationHandler
    let info = ConnectionInfo(
      endpointName: names[endpointID], authDigits: verificationCode,
      isIncoming: incoming.contains(endpointID))
    emit { try await $0.onConnectionInitiated(endpointId: endpointID, info: info) }
  }

  public func connectionManager(
    _ connectionManager: ConnectionManager, didChangeTo state: ConnectionState, for endpointID: EndpointID
  ) {
    switch state {
    case .connecting:
      return
    case .connected:
      connected.insert(endpointID)
      emit { try await $0.onConnectionResult(endpointId: endpointID, statusCode: Self.statusOK) }
    case .rejected:
      forget(endpointID)
      emit { try await $0.onConnectionResult(endpointId: endpointID, statusCode: Self.statusRejected) }
    case .disconnected:
      let wasConnected = connected.contains(endpointID)
      forget(endpointID)
      if wasConnected {
        emit { try await $0.onDisconnected(endpointId: endpointID) }
      } else {
        emit { try await $0.onConnectionResult(endpointId: endpointID, statusCode: Self.statusError) }
      }
    }
  }

  public func connectionManager(
    _ connectionManager: ConnectionManager, didReceive data: Data, withID payloadID: PayloadID,
    from endpointID: EndpointID
  ) {
    let payload = PayloadMessage(id: payloadID, type: 1, bytes: FlutterStandardTypedData(bytes: data))
    emit { try await $0.onPayloadReceived(endpointId: endpointID, payload: payload) }
  }

  public func connectionManager(
    _ connectionManager: ConnectionManager, didReceive stream: InputStream, withID payloadID: PayloadID,
    from endpointID: EndpointID, cancellationToken token: CancellationToken
  ) {
    // Streams aren't part of the Pigeon API; surface the payload so Dart can cancel it.
    tokens[payloadID] = token
    emit { try await $0.onPayloadReceived(endpointId: endpointID, payload: PayloadMessage(id: payloadID, type: 3)) }
  }

  public func connectionManager(
    _ connectionManager: ConnectionManager, didStartReceivingResourceWithID payloadID: PayloadID,
    from endpointID: EndpointID, at localURL: URL, withName name: String,
    cancellationToken token: CancellationToken
  ) {
    tokens[payloadID] = token
    let payload = PayloadMessage(id: payloadID, type: 2, filePath: localURL.path)
    emit { try await $0.onPayloadReceived(endpointId: endpointID, payload: payload) }
  }

  public func connectionManager(
    _ connectionManager: ConnectionManager, didReceiveTransferUpdate update: NearbyConnections.TransferUpdate,
    from endpointID: EndpointID, forPayload payloadID: PayloadID
  ) {
    // Android `PayloadTransferUpdate.Status`: 1 success, 2 failure, 3 in progress, 4 canceled.
    let message: TransferUpdate
    switch update {
    case .success: message = TransferUpdate(payloadId: payloadID, status: 1)
    case .failure: message = TransferUpdate(payloadId: payloadID, status: 2)
    case .canceled: message = TransferUpdate(payloadId: payloadID, status: 4)
    case .progress(let progress):
      message = TransferUpdate(
        payloadId: payloadID, status: 3, bytesTransferred: progress.completedUnitCount,
        totalBytes: progress.totalUnitCount)
    }
    if message.status != 3 { tokens[payloadID] = nil }
    emit { try await $0.onPayloadTransferUpdate(endpointId: endpointID, update: message) }
  }
}
