import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:rd_manager/secrets.dart' as secrets;

/// Lightweight value object representing a repository.
class RepoData {
  final String userName;
  final String repoName;
  final bool isReadOnly;

  const RepoData({
    required this.userName,
    required this.repoName,
    this.isReadOnly = false,
  });

  RepoData copyWith({String? userName, String? repoName, bool? isReadOnly}) {
    return RepoData(
      userName: userName ?? this.userName,
      repoName: repoName ?? this.repoName,
      isReadOnly: isReadOnly ?? this.isReadOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'repoName': repoName,
    'isReadOnly': isReadOnly,
  };

  /// Be lenient when parsing stored data — callers (load) handle malformed
  /// entries by skipping them.
  static RepoData fromJson(Map<String, dynamic> json) {
    final user = json['userName'];
    final repo = json['repoName'];
    final readOnly = json['isReadOnly'] as bool? ?? false;
    if (user is! String || repo is! String) {
      throw const FormatException('Invalid RepoData JSON');
    }
    return RepoData(userName: user, repoName: repo, isReadOnly: readOnly);
  }

  @override
  String toString() =>
      'RepoData($userName/$repoName${isReadOnly ? ', readOnly' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoData &&
          userName.toLowerCase() == other.userName.toLowerCase() &&
          repoName.toLowerCase() == other.repoName.toLowerCase() &&
          isReadOnly == other.isReadOnly;

  @override
  int get hashCode =>
      Object.hash(userName.toLowerCase(), repoName.toLowerCase(), isReadOnly);
}

const String _repoStorageKey = 'repo_list';

/// Persistence helper extracted for clarity and easier testing.
class RepoStorage {
  const RepoStorage._();

  static Future<void> save(List<RepoData> repos) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> stringList = repos
        .where((r) => !r.isReadOnly)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList(_repoStorageKey, stringList);
  }

  static Future<List<RepoData>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? raw = prefs.getStringList(_repoStorageKey);
    final List<RepoData> result = [];

    if (raw != null) {
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            result.add(RepoData.fromJson(Map<String, dynamic>.from(decoded)));
          }
        } catch (e) {
          log('Malformed entry: $e');
          // keep running on malformed entries
        }
      }
    }

    final List<RepoData> defaultRepos = [
      RepoData(
        userName: secrets.userName1,
        repoName: secrets.repoName1,
        isReadOnly: true,
      ),
    ];

    for (final dr in defaultRepos) {
      result.removeWhere(
        (r) =>
            r.userName.toLowerCase() == dr.userName.toLowerCase() &&
            r.repoName.toLowerCase() == dr.repoName.toLowerCase(),
      );
    }
    result.insertAll(0, defaultRepos);
    return result;
  }
}

// Backward-compatible top-level functions
Future<void> saveRepoDataList(List<RepoData> repos) => RepoStorage.save(repos);
Future<List<RepoData>> loadRepoDataList() => RepoStorage.load();
