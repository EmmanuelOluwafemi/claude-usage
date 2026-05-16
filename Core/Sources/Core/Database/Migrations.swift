import Foundation
import GRDB

enum Migrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: Schema.createClaudeTurns)
            try db.execute(sql: Schema.createCodexObservations)
            try db.execute(sql: Schema.createFileCursors)
            try db.execute(sql: Schema.createLimitsState)
            try db.execute(sql: Schema.createDailyAggregates)
            for indexSQL in Schema.indexes {
                try db.execute(sql: indexSQL)
            }
        }

        return migrator
    }
}
