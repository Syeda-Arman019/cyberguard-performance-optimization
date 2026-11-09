package com.example.cyberguard_mobile.performance.sampling

import com.example.cyberguard_mobile.performance.data.PerfChargingState
import com.example.cyberguard_mobile.performance.data.PerfPluggedType

/*****
 * Pure functions that map raw Android battery ints to our canonical string constants.
 * No Android APIs, no Context, no database: these can be unit-tested outside an APK.
 ****/

/// Maps the raw battery status extra to a [PerfChargingState] string.
/// [status] is the int from BatteryManager.EXTRA_STATUS (or the task's numbering:
///   1=unknown, 2=charging, 3=discharging, 4=not_charging, 5=full; null→unknown).
/// [plugged] is the bitmask from BatteryManager.EXTRA_PLUGGED (1=AC, 2=USB, 4=WIRELESS, 8=DOCK).
/// Returns the charging state string; null status always yields UNKNOWN.
fun mapChargingState(status: Int?, plugged: Int?): String {
    return when {
        status == null -> PerfChargingState.UNKNOWN
        status == 1 -> PerfChargingState.UNKNOWN
        status == 2 -> PerfChargingState.CHARGING
        status == 3 -> PerfChargingState.DISCHARGING
        status == 4 -> PerfChargingState.NOT_CHARGING
        status == 5 -> PerfChargingState.FULL
        else -> PerfChargingState.UNKNOWN
    }
}

/// Maps the raw plugged bitmask to a [PerfPluggedType] string.
/// [plugged] is a BITMASK: 1=AC, 2=USB, 4=WIRELESS, 8=DOCK.
/// Priority when several bits are set: AC > USB > WIRELESS > DOCK.
/// If [plugged] is null or 0, returns the appropriate constant.
/// plugged_type is never "none" when any bit is set.
fun mapPluggedType(plugged: Int?): String {
    if (plugged == null) return PerfPluggedType.UNKNOWN
    if (plugged == 0) return PerfPluggedType.NONE

    // Priority: AC(1) > USB(2) > WIRELESS(4) > DOCK(8)
    return if ((plugged and 1) != 0) PerfPluggedType.AC
    else if ((plugged and 2) != 0) PerfPluggedType.USB
    else if ((plugged and 4) != 0) PerfPluggedType.WIRELESS
    else if ((plugged and 8) != 0) PerfPluggedType.DOCK
    else PerfPluggedType.UNKNOWN
}