package com.virasat.virasat_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import kotlin.math.PI
import kotlin.math.asin
import kotlin.math.atan2

/**
 * Streams device orientation to Dart as W3C DeviceOrientationEvent angles
 * [alpha, beta, gamma] in degrees.
 *
 * Android WebView only delivers `deviceorientation` to secure (https) pages,
 * so the VR explorer served over plain http on the LAN never sees the gyro.
 * Dart forwards these readings into the page (see orientation_polyfill.dart).
 */
class MainActivity : FlutterActivity(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var sensor: Sensor? = null
    private var sink: EventChannel.EventSink? = null
    private val rot = FloatArray(9)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        // Game rotation vector: gyro + accel, no magnetometer → no compass jumps.
        sensor = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "virasat/orientation")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    sink = events
                    start()
                }

                override fun onCancel(args: Any?) {
                    stop()
                    sink = null
                }
            })
    }

    private fun start() {
        sensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
    }

    private fun stop() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
    }

    override fun onResume() {
        super.onResume()
        if (sink != null) start()
    }

    override fun onPause() {
        stop()
        super.onPause()
    }

    override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent) {
        val out = sink ?: return
        SensorManager.getRotationMatrixFromVector(rot, event.values)
        out.success(eulerFromRotation(rot))
    }

    /** Same conversion Chromium uses to produce DeviceOrientationEvent angles. */
    private fun eulerFromRotation(r: FloatArray): DoubleArray {
        val r0 = r[0].toDouble(); val r1 = r[1].toDouble(); val r3 = r[3].toDouble()
        val r4 = r[4].toDouble(); val r6 = r[6].toDouble(); val r7 = r[7].toDouble()
        val r8 = r[8].toDouble()
        var alpha: Double
        var beta: Double
        val gamma: Double
        if (r8 > 0) {
            alpha = atan2(-r1, r4); beta = asin(r7); gamma = atan2(-r6, r8)
        } else if (r8 < 0) {
            alpha = atan2(r1, -r4); beta = -asin(r7)
            beta += if (beta >= 0) -PI else PI
            gamma = atan2(r6, -r8)
        } else if (r6 > 0) {
            alpha = atan2(-r1, r4); beta = asin(r7); gamma = -PI / 2
        } else if (r6 < 0) {
            alpha = atan2(r1, -r4); beta = -asin(r7)
            beta += if (beta >= 0) -PI else PI
            gamma = -PI / 2
        } else {
            alpha = atan2(r3, r0); beta = if (r7 > 0) PI / 2 else -PI / 2; gamma = 0.0
        }
        if (alpha < 0) alpha += 2 * PI
        val deg = 180.0 / PI
        return doubleArrayOf(alpha * deg, beta * deg, gamma * deg)
    }
}
