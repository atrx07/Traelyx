package io.github.atrx07.traelyx.recorder

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/** QA-only foreground host: no Flutter/account initialization. */
class RecorderHardeningActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        check(packageName == "io.github.atrx07.traelyx.hardening")
        setContentView(TextView(this).apply { text = "Traelyx recorder QA — stationary test" })
    }
}
