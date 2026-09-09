package com.example.printer_agent

import android.app.Activity
import android.os.Bundle

/// Receives USB_DEVICE_ATTACHED so Android grants persistent USB permission for
/// the printer, then closes immediately. Handling the intent here instead of on
/// MainActivity keeps the app from being pulled to the foreground when the
/// printer attaches or re-enumerates.
class UsbAttachActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        finish()
    }
}
