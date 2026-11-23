package com.example.card_reader

import android.content.Context
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class HceService : HostApduService() {

    companion object {
        private const val TAG = "HceService"

        // Default TLV payload: Device Name = "Android Phone", Message = "Hello via NFC!"
        private val DEFAULT_PAYLOAD = byteArrayOf(
            0x01.toByte(), 0x0D.toByte(),
            'A'.code.toByte(), 'n'.code.toByte(), 'd'.code.toByte(), 'r'.code.toByte(), 'o'.code.toByte(),
            'i'.code.toByte(), 'd'.code.toByte(), ' '.code.toByte(), 'P'.code.toByte(), 'h'.code.toByte(),
            'o'.code.toByte(), 'n'.code.toByte(), 'e'.code.toByte(),
            0x02.toByte(), 0x0E.toByte(),
            'H'.code.toByte(), 'e'.code.toByte(), 'l'.code.toByte(), 'l'.code.toByte(), 'o'.code.toByte(),
            ' '.code.toByte(), 'v'.code.toByte(), 'i'.code.toByte(), 'a'.code.toByte(), ' '.code.toByte(),
            'N'.code.toByte(), 'F'.code.toByte(), 'C'.code.toByte(), '!'.code.toByte()
        )

        // Shared payload encoded by Rust
        var currentPayload: ByteArray = byteArrayOf()

        private val SELECT_APDU_HEADER = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte()
        )
        private val STATUS_SUCCESS = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val STATUS_FAILED = byteArrayOf(0x6F.toByte(), 0x00.toByte())
    }

    private fun getActivePayload(): ByteArray {
        if (currentPayload.isNotEmpty()) {
            return currentPayload
        }

        // Load from disk if the app was closed or device rebooted
        try {
            val prefs = getSharedPreferences("hce_prefs", Context.MODE_PRIVATE)
            val hex = prefs.getString("saved_payload", null)
            if (!hex.isNullOrEmpty()) {
                val bytes = ByteArray(hex.length / 2)
                for (i in 0 until hex.length step 2) {
                    bytes[i / 2] = hex.substring(i, i + 2).toInt(16).toByte()
                }
                currentPayload = bytes
                return bytes
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading saved payload: $e")
        }

        return DEFAULT_PAYLOAD
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return STATUS_FAILED

        val hexCmd = commandApdu.joinToString("") { "%02X".format(it) }
        Log.d(TAG, "HCE received APDU: >> $hexCmd")

        // Check if command is SELECT AID (starts with 00 A4 04 00)
        if (commandApdu.size >= 4 &&
            commandApdu[0] == SELECT_APDU_HEADER[0] &&
            commandApdu[1] == SELECT_APDU_HEADER[1] &&
            commandApdu[2] == SELECT_APDU_HEADER[2] &&
            commandApdu[3] == SELECT_APDU_HEADER[3]
        ) {
            val payload = getActivePayload()
            Log.d(TAG, "HCE responding with ${payload.size} payload bytes + 90 00")
            return payload + STATUS_SUCCESS
        }

        return STATUS_FAILED
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "HCE deactivated. Reason: $reason")
    }
}
