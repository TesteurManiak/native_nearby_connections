package com.maniak.native_nearby_connections

import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo as GmsConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/** NativeNearbyConnectionsPlugin: bridges Google Nearby Connections to Dart via Pigeon. */
class NativeNearbyConnectionsPlugin : FlutterPlugin, NearbyHostApi {
    private lateinit var client: ConnectionsClient
    private lateinit var flutterApi: NearbyFlutterApi
    private lateinit var scope: CoroutineScope

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        client = Nearby.getConnectionsClient(binding.applicationContext)
        flutterApi = NearbyFlutterApi(binding.binaryMessenger)
        scope = MainScope()
        NearbyHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NearbyHostApi.setUp(binding.binaryMessenger, null)
        client.stopAdvertising()
        client.stopDiscovery()
        client.stopAllEndpoints()
        scope.cancel()
    }

    /** Fire-and-forget to Dart; a missing Dart listener must not crash native callbacks. */
    private fun emit(block: suspend NearbyFlutterApi.() -> Unit) {
        scope.launch { runCatching { flutterApi.block() } }
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: GmsConnectionInfo) = emit {
            onConnectionInitiated(
                endpointId,
                ConnectionInfo(info.endpointName, info.authenticationDigits, info.isIncomingConnection),
            )
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) = emit {
            onConnectionResult(endpointId, result.status.statusCode.toLong())
        }

        override fun onDisconnected(endpointId: String) = emit { onDisconnected(endpointId) }
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) = emit {
            onEndpointFound(EndpointInfo(endpointId, info.endpointName, info.serviceId))
        }

        override fun onEndpointLost(endpointId: String) = emit { onEndpointLost(endpointId) }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) = emit {
            val file = payload.asFile()
            @Suppress("DEPRECATION") // asJavaFile is null on Android Q+, fall back to the content URI.
            val filePath = file?.asJavaFile()?.absolutePath ?: file?.asUri()?.toString()
            onPayloadReceived(
                endpointId,
                PayloadMessage(payload.id, payload.type.toLong(), payload.asBytes(), filePath),
            )
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) = emit {
            onPayloadTransferUpdate(
                endpointId,
                TransferUpdate(update.payloadId, update.status.toLong(), update.bytesTransferred, update.totalBytes),
            )
        }
    }

    private fun NearbyStrategy.toGms(): Strategy = when (this) {
        NearbyStrategy.CLUSTER -> Strategy.P2P_CLUSTER
        NearbyStrategy.STAR -> Strategy.P2P_STAR
        NearbyStrategy.POINT_TO_POINT -> Strategy.P2P_POINT_TO_POINT
    }

    override suspend fun startAdvertising(name: String, serviceId: String, strategy: NearbyStrategy) {
        // A session left over from before a Dart hot restart would fail with STATUS_ALREADY_ADVERTISING.
        client.stopAdvertising()
        val options = AdvertisingOptions.Builder().setStrategy(strategy.toGms()).build()
        client.startAdvertising(name, serviceId, connectionLifecycleCallback, options).await()
    }

    override suspend fun startDiscovery(serviceId: String, strategy: NearbyStrategy) {
        // A session left over from before a Dart hot restart would fail with STATUS_ALREADY_DISCOVERING.
        client.stopDiscovery()
        val options = DiscoveryOptions.Builder().setStrategy(strategy.toGms()).build()
        client.startDiscovery(serviceId, endpointDiscoveryCallback, options).await()
    }

    override suspend fun requestConnection(name: String, endpointId: String) {
        client.requestConnection(name, endpointId, connectionLifecycleCallback).await()
    }

    override suspend fun acceptConnection(endpointId: String) {
        client.acceptConnection(endpointId, payloadCallback).await()
    }

    override suspend fun rejectConnection(endpointId: String) {
        client.rejectConnection(endpointId).await()
    }

    override suspend fun sendBytes(endpointIds: List<String>, bytes: ByteArray): Long {
        val payload = Payload.fromBytes(bytes)
        client.sendPayload(endpointIds, payload).await()
        return payload.id
    }

    override suspend fun sendFile(endpointIds: List<String>, path: String): Long {
        val payload = Payload.fromFile(File(path))
        client.sendPayload(endpointIds, payload).await()
        return payload.id
    }

    override fun cancelPayload(payloadId: Long) {
        client.cancelPayload(payloadId)
    }

    override fun stopAdvertising() = client.stopAdvertising()

    override fun stopDiscovery() = client.stopDiscovery()

    override fun disconnect(endpointId: String) = client.disconnectFromEndpoint(endpointId)

    override fun stopAllEndpoints() = client.stopAllEndpoints()
}
