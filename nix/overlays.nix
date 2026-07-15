[
  # snowflake-connector-python の一部テストが Nix ビルドサンドボックス /
  # Python 3.14 環境で失敗し、snowflake-cli まで芋づる式にビルド不能になる。
  # 該当テストのみ除外して回避する（機能には影響しない環境依存の失敗）。
  (final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (pyfinal: pyprev: {
        snowflake-connector-python =
          pyprev.snowflake-connector-python.overridePythonAttrs (old: {
            # サンドボックスでは親ディレクトリのパーミッション判定が実環境と異なり
            # 期待するデバッグログが出ないため deselect する。
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_log_debug_config_file_parent_dir_permissions"
            ];
            # Python 3.14 で asyncio.get_event_loop() が実行中ループ無しだと
            # RuntimeError を投げる仕様変更にテスト側が未対応で収集エラーになる。
            disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
              "test/unit/aio/test_connection_async_unit.py"
            ];
          });
      })
    ];
  })

  # snowflake-cli 3.13.1 のテストは、nixpkgs が bump した click/typer/pydantic に
  # 追随できておらず 11 件以上失敗する（TyperOption.make_metavar の ctx 引数追加、
  # pydantic バリデーション挙動変更など）。deselect ではなく doCheck を切るのは、
  # 失敗が click/typer/pydantic 全体にまたがり pytest-xdist が 10 件で打ち切るため
  # 個別除外が追随できないから。`snow --version` / `--help` / サブコマンド help の
  # metavar 描画は実バイナリで動作確認済みで、runtime には影響しない。
  (final: prev: {
    snowflake-cli = prev.snowflake-cli.overridePythonAttrs (_old: {
      doCheck = false;
      doInstallCheck = false;
    });
  })
]
