package com.example.cyberguard_mobile.performance.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration

/**
 * The module's single Room database.
 *
 * Schema export: the KSP argument `room.schemaLocation` (see app/build.gradle.kts) writes the
 * version-1 schema JSON to android/app/schemas/. Commit those files: they are what future
 * migrations are diffed against.
 *
 * Migrations: [MIGRATIONS] is empty at version 1. Any future change must
 *   1. add a [Migration] to [MIGRATIONS], and
 *   2. bump [VERSION].
 * There is deliberately no `fallbackToDestructiveMigration()`: losing the user's history
 * silently would be worse than a loud, fixable crash.
 */
@Database(
    entities = [
        PerfSampleEntity::class,
        PerfCapabilityEntity::class,
        PerfDeviceInfoEntity::class,
        PerfAppStorageEntity::class,
        PerfHeatSessionEntity::class,
        PerfFindingEntity::class,
        PerfExpectedEntity::class,
        PerfChargingSessionEntity::class,
    ],
    version = PerfDatabase.VERSION,
    exportSchema = true,
)
abstract class PerfDatabase : RoomDatabase() {

    abstract fun perfDao(): PerfDao

    companion object {
        /** Current schema version. Bump together with a new entry in [MIGRATIONS]. */
        const val VERSION: Int = 1

        /** Database file name; prefixed so it cannot collide with another module's database. */
        const val DATABASE_NAME: String = "perf_cyberguard.db"

        /**
         * Explicit migrations, in ascending order. Example for a future version 1 -> 2:
         *
         *   val MIGRATION_1_2 = object : Migration(1, 2) {
         *       override fun migrate(db: SupportSQLiteDatabase) {
         *           db.execSQL("ALTER TABLE perf_samples ADD COLUMN example INTEGER")
         *       }
         *   }
         */
        private val MIGRATIONS: Array<Migration> = emptyArray()

        @Volatile
        private var instance: PerfDatabase? = null

        /**
         * Process-wide singleton. Cheap to call from any thread; the first call builds
         * the database lazily and Room opens the file on first use.
         */
        fun get(context: Context): PerfDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    PerfDatabase::class.java,
                    DATABASE_NAME,
                )
                    .addMigrations(*MIGRATIONS)
                    .build()
                    .also { instance = it }
            }
        }
    }
}
