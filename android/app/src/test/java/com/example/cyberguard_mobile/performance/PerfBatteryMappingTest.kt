package com.example.cyberguard_mobile.performance

import com.example.cyberguard_mobile.performance.sampling.mapChargingState
import com.example.cyberguard_mobile.performance.sampling.mapPluggedType
import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for the battery mapping pure functions.
 * 
 * Tests cover the mapChargingState and mapPluggedType functions in PerfBatteryMapping.kt.
 * All data is derived from real Android battery constants; no mock or fake values.
 */
class PerfBatteryMappingTest {

    @Test
    fun `mapChargingState with status 1 (unknown) returns UNKNOWN`() {
        assertEquals(PerfChargingState.UNKNOWN, mapChargingState(null, null))
        assertEquals(PerfChargingState.UNKNOWN, mapChargingState(1, 0))
    }

    @Test
    fun `mapChargingState with status 2 (charging) returns CHARGING`() {
        assertEquals(PerfChargingState.CHARGING, mapChargingState(2, 1))
        assertEquals(PerfChargingState.CHARGING, mapChargingState(2, 2))
        assertEquals(PerfChargingState.CHARGING, mapChargingState(2, 3))
    }

    @Test
    fun `mapChargingState with status 3 (discharging) returns DISCHARGING`() {
        assertEquals(PerfChargingState.DISCHARGING, mapChargingState(3, 0))
        assertEquals(PerfChargingState.DISCHARGING, mapChargingState(3, 1))
    }

    @Test
    fun `mapChargingState with status 4 (not charging) returns NOT_CHARGING`() {
        assertEquals(PerfChargingState.NOT_CHARGING, mapChargingState(4, 0))
    }

    @Test
    fun `mapChargingState with status 5 (full) returns FULL`() {
        assertEquals(PerfChargingState.FULL, mapChargingState(5, 0))
    }

    @Test
    fun `mapPluggedType with null returns UNKNOWN`() {
        assertEquals(PerfPluggedType.UNKNOWN, mapPluggedType(null))
    }

    @Test
    fun `mapPluggedType with 0 (none) returns NONE`() {
        assertEquals(PerfPluggedType.NONE, mapPluggedType(0))
    }

    @Test
    fun `mapPluggedType with AC (bit 1) returns AC`() {
        assertEquals(PerfPluggedType.AC, mapPluggedType(1))
    }

    @Test
    fun `mapPluggedType with USB (bit 2) returns USB`() {
        assertEquals(PerfPluggedType.USB, mapPluggedType(2))
    }

    @Test
    fun `mapPluggedType with wireless (bit 4) returns WIRELESS`() {
        assertEquals(PerfPluggedType.WIRELESS, mapPluggedType(4))
    }

    @Test
    fun `mapPluggedType with dock (bit 8) returns DOCK`() {
        assertEquals(PerfPluggedType.DOCK, mapPluggedType(8))
    }

    @Test
    fun `mapPluggedType with combined bitmask AC+USB returns AC (priority)`() {
        // 1 (AC) | 2 (USB) = 3, priority: AC wins
        assertEquals(PerfPluggedType.AC, mapPluggedType(3))
    }

    @Test
    fun `mapPluggedType with combined bitmask USB+DOCK returns USB (priority)`() {
        // 2 (USB) | 8 (DOCK) = 10, priority: USB wins over DOCK
        assertEquals(PerfPluggedType.USB, mapPluggedType(10))
    }

    @Test
    fun `mapPluggedType with combined bitmask AC+USB+wireless+DOCK returns AC`() {
        // 1 | 2 | 4 | 8 = 15, AC has highest priority
        assertEquals(PerfPluggedType.AC, mapPluggedType(15))
    }

    @Test
    fun `mapPluggedType with no bits set returns NONE`() {
        assertEquals(PerfPluggedType.NONE, mapPluggedType(0))
    }
}