import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/game.dart';
import '../models/player.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('skullking.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE manche_scores ADD COLUMN colored_fourteens INTEGER DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE manche_scores ADD COLUMN black_fourteen INTEGER DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE manche_scores ADD COLUMN captured_mermaids INTEGER DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE manche_scores ADD COLUMN captured_pirates INTEGER DEFAULT 0',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE manche_scores ADD COLUMN skullking_captured INTEGER DEFAULT 0',
        );
      } catch (_) {}
    }

    if (oldVersion < 3) {
      await db.execute('''
      CREATE TABLE games_temp(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL
      )
    ''');
      await db.execute('''
      INSERT INTO games_temp (id, date)
      SELECT id, date FROM games
    ''');
      await db.execute('DROP TABLE games');
      await db.execute('ALTER TABLE games_temp RENAME TO games');
    }

    if (oldVersion < 4) {
      await db.execute('''
      CREATE TABLE game_players_temp(
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        player_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(game_id, player_order)
      )
    ''');

      await db.execute('''
      INSERT INTO game_players_temp (game_id, player_id, player_order)
      SELECT game_id, player_id, 
        (SELECT COUNT(*) 
         FROM game_players gp2 
         WHERE gp2.game_id = gp1.game_id AND gp2.player_id <= gp1.player_id) - 1
      FROM game_players gp1
    ''');

      await db.execute('DROP TABLE game_players');
      await db.execute('ALTER TABLE game_players_temp RENAME TO game_players');
    }

    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE game_players ADD COLUMN player_final_score INTEGER DEFAULT NULL',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE game_players ADD COLUMN player_total_bet INTEGER DEFAULT NULL',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE game_players ADD COLUMN player_total_plis INTEGER DEFAULT NULL',
        );
      } catch (_) {}

      final games = await db.query('games');
      for (final game in games) {
        final gameId = game['id'] as int;

        final players = await db.rawQuery(
          'SELECT player_id FROM game_players WHERE game_id = ?',
          [gameId],
        );

        bool allComplete = true;
        for (final player in players) {
          final playerId = player['player_id'] as int;

          final result = await db.rawQuery(
            '''
        SELECT COUNT(*) AS completeCount
        FROM manche_scores
        WHERE game_id = ? AND player_id = ?
        AND pari IS NOT NULL AND plis IS NOT NULL
        ''',
            [gameId, playerId],
          );

          final totalManches =
              Sqflite.firstIntValue(
                await db.rawQuery(
                  '''
        SELECT COUNT(DISTINCT manche_num)
        FROM manche_scores
        WHERE game_id = ?
      ''',
                  [gameId],
                ),
              ) ??
              10;

          final completeCount = result.first['completeCount'] as int;
          if (completeCount < totalManches) {
            allComplete = false;
            break;
          }
        }

        if (allComplete) {
          for (final player in players) {
            final playerId = player['player_id'] as int;
            final totalResult = await db.rawQuery(
              '''
          SELECT 
            SUM(
              CASE
                WHEN pari = plis AND pari != 0 THEN (20 * pari) + COALESCE(bonus, 0)
                WHEN pari = 0 THEN 
                  CASE 
                    WHEN plis = 0 THEN (10 * manche_num) + COALESCE(bonus, 0)
                    ELSE -10 * manche_num
                  END
                ELSE -10 * ABS(pari - plis)
              END
            ) AS total
          FROM manche_scores
          WHERE game_id = ? AND player_id = ?
          ''',
              [gameId, playerId],
            );

            final totalScore = (totalResult.first['total'] ?? 0) as int;

            final totalBetData = await db.rawQuery(
              '''
              SELECT SUM(pari) AS total_bet
              FROM manche_scores
              WHERE game_id = ? AND player_id = ?
              ''',
              [gameId, playerId],
            );

            final totalBet = (totalBetData.first['total_bet'] ?? 0) as int;

            final totalPlisData = await db.rawQuery(
              '''          
              SELECT SUM(plis) AS total_plis
              FROM manche_scores
              WHERE game_id = ? AND player_id = ?
              ''',
              [gameId, playerId],
            );

            final totalPlis = (totalPlisData.first['total_plis'] ?? 0) as int;

            await db.update(
              'game_players',
              {
                'player_final_score': totalScore,
                'player_total_bet': totalBet,
                'player_total_plis': totalPlis,
              },
              where: 'game_id = ? AND player_id = ?',
              whereArgs: [gameId, playerId],
            );
          }
        }
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE games(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE game_players(
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        player_order INTEGER NOT NULL,
        player_final_score INTEGER DEFAULT NULL,
        player_total_bet INTEGER DEFAULT NULL,
        player_total_plis INTEGER DEFAULT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(game_id, player_order)
      )
    ''');

    await db.execute('''
      CREATE TABLE manche_scores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        manche_num INTEGER NOT NULL,
        pari INTEGER,
        plis INTEGER,
        bonus INTEGER DEFAULT 0,
        colored_fourteens INTEGER DEFAULT 0,
        black_fourteen INTEGER DEFAULT 0,
        captured_mermaids INTEGER DEFAULT 0,
        captured_pirates INTEGER DEFAULT 0,
        skullking_captured INTEGER DEFAULT 0,
        FOREIGN KEY (game_id) REFERENCES games (id) ON DELETE CASCADE,
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(game_id, player_id, manche_num) ON CONFLICT REPLACE
      )
    ''');
  }

  // Games
  Future<int> insertGame(Game game) async {
    final db = await instance.database;
    return await db.insert('games', {
      'id': game.id,
      'date': game.date,
    });
  }

  Future<List<Game>> getAllGames() async {
    final db = await instance.database;
    final games = await db.query('games', orderBy: 'id DESC');

    List<Game> result = [];
    for (var gameMap in games) {
      final game = Game.fromMap(gameMap);
      final players = await getPlayersForGame(game.id!);
      game.players = players.map((p) => p.name).toList();
      result.add(game);
    }
    return result;
  }

  // Players
  Future<List<Player>> getAllPlayers() async {
    final db = await instance.database;
    final result = await db.query('players', orderBy: 'name');
    return result.map((json) => Player.fromMap(json)).toList();
  }

  Future<int> insertPlayer(Player player) async {
    final db = await instance.database;
    return await db.insert('players', player.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Game-Player link
  Future<void> linkPlayerToGame(
    int gameId,
    int playerId, {
    required int order,
  }) async {
    final db = await database;
    await db.insert('game_players', {
      'game_id': gameId,
      'player_id': playerId,
      'player_order': order,
    });
  }

  Future<List<Player>> getPlayersForGame(int gameId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT p.id, p.name FROM players p
      INNER JOIN game_players gp ON p.id = gp.player_id
      WHERE gp.game_id = ?
      ORDER BY gp.player_order
    ''', [gameId]);
    return result.map((e) => Player.fromMap(e)).toList();
  }

  // Manche scores
  Future<void> saveMancheScore(
    int gameId,
    int playerId,
    int mancheNum,
    Map<String, int?> data,
  ) async {
    final db = await instance.database;
    await db.insert('manche_scores', {
      'game_id': gameId,
      'player_id': playerId,
      'manche_num': mancheNum,
      'pari': data['pari'],
      'plis': data['plis'],
      'bonus': data['bonus'] ?? 0,
      'colored_fourteens': data['colored_fourteens'] ?? 0,
      'black_fourteen': data['black_fourteen'] ?? 0,
      'captured_mermaids': data['captured_mermaids'] ?? 0,
      'captured_pirates': data['captured_pirates'] ?? 0,
      'skullking_captured': data['skullking_captured'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveGameScore(
    int gameId,
    int playerId,
    int playerFinalScore,
    int playerTotalBet,
    int playerTotalPlis,
  ) async {
    final db = await instance.database;
    await db.update(
      'game_players',
      {
        'player_final_score': playerFinalScore,
        'player_total_bet': playerTotalBet,
        'player_total_plis': playerTotalPlis,
      },
      where: 'game_id = ? AND player_id = ?',
      whereArgs: [gameId, playerId],
    );
  }

  Future<Map<int, Map<int, Map<String, int?>>>> getAllMancheScores(
    int gameId,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'manche_scores',
      where: 'game_id = ?',
      whereArgs: [gameId],
    );

    final scores = <int, Map<int, Map<String, int?>>>{};
    for (final row in result) {
      final mancheNum = row['manche_num'] as int;
      final playerId = row['player_id'] as int;

      scores.putIfAbsent(mancheNum, () => {});
      scores[mancheNum]!.putIfAbsent(playerId, () => {});

      scores[mancheNum]![playerId] = {
        'pari': row['pari'] as int?,
        'plis': row['plis'] as int?,
        'bonus': row['bonus'] as int?,
        'colored_fourteens': row['colored_fourteens'] as int?,
        'black_fourteen': row['black_fourteen'] as int?,
        'captured_mermaids': row['captured_mermaids'] as int?,
        'captured_pirates': row['captured_pirates'] as int?,
        'skullking_captured': row['skullking_captured'] as int?,
      };
    }
    return scores;
  }

  Future<Map<int, Map<int, Map<String, int?>>>> getAllPlayerStats() async {
    final db = await instance.database;
    final result = await db.query('game_players');

    final stats = <int, Map<int, Map<String, int?>>>{};

    final games = <int, List<Map<String, dynamic>>>{};
    for (final row in result) {
      final gameId = row['game_id'] as int;
      games.putIfAbsent(gameId, () => []);
      games[gameId]!.add(row);
    }

    for (final gameEntry in games.entries) {
      final gameId = gameEntry.key;
      final players = gameEntry.value;

      final allHaveScores = players.every(
        (p) => p['player_final_score'] != null,
      );

      if (!allHaveScores) {
        continue;
      }

      final maxScore = players
          .map((p) => p['player_final_score'] as int? ?? 0)
          .fold<int>(0, (prev, elem) => elem > prev ? elem : prev);

      for (final player in players) {
        final playerId = player['player_id'] as int;
        final score = player['player_final_score'] as int?;

        if (score == null) continue;

      stats.putIfAbsent(playerId, () => {});
        stats[playerId]!.putIfAbsent(gameId, () => {});

        stats[playerId]![gameId] = {
          'player_final_score': score,
          'player_total_bet': player['player_total_bet'] as int?,
          'player_total_plis': player['player_total_plis'] as int?,
          'win': score == maxScore ? 1 : 0,
      };
    }
    }

    return stats;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}