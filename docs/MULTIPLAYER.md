# 共同世界 · 8–32 人合作 PvE

此版本把所有連到同一個位址的玩家放進同一張世界地圖。村莊、城堡、野外與 Boss 都在同一台伺服器運行，最多 32 位玩家；沒有分房間或副本。現階段是可測試的合作原型，尚未部署公開伺服器。

## 一起遊玩

1. 在負責開服的 Mac 雙擊專案中的 `Server.command`。終端出現 `REALM_READY port=24567 capacity=32` 即已就緒；保留終端並讓電腦持續運行。
2. Mac 玩家用相同版本的完整專案開啟 `Aurelia.app`；Windows 玩家解壓縮 `builds/Aurelia-Windows.zip`，開啟 `Aurelia.exe`。選「多人聯機 · 共同世界」，填角色名稱、同一個伺服器位址和連接埠 `24567`，按「加入共同世界」。
3. 在開服的同一台電腦玩，位址填 `127.0.0.1`。同一個區域網路的其他電腦，填開服電腦的區網 IP；`127.0.0.1` 只會連回自己的電腦。

也可直接在遊戲選「在此電腦開啟世界」，讓主機玩家一起冒險。此模式的主機離開共同世界時，其他玩家會斷線。獨立的 `Server.command` 則會在沒有人在線時繼續維持世界。

跨網路的朋友需要能從外網到達的伺服器位址，以及允許 UDP `24567` 的防火牆／路由器轉送或公網主機。目前沒有自動設定路由器、租用主機或對外部署。Godot 高階聯機使用 ENet / UDP，外網設定可參考 [Godot 官方聯機文件](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)。

命令列（在專案根目錄執行）：

```sh
# 開獨立伺服器；自訂連接埠時，所有玩家也要填相同值。
tools/Godot.app/Contents/MacOS/Godot --headless --path . -- --server --port=24567

# 同一台電腦加入。
tools/Godot.app/Contents/MacOS/Godot --path . -- --join=127.0.0.1 --port=24567 --name=青葉
```

Windows x86-64 已提供獨立測試包，匯出資源已檢查，但尚未在 Windows 實機驗證。其他作業系統可用相同 Godot 4.6 版本開啟專案。伺服器執行方式依據 [Godot 獨立伺服器文件](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html)。

## 共享與個人狀態

| 項目 | 聯機行為 |
| --- | --- |
| 玩家動作 | 移動、奔跑、翻滾、騎馬、劍技及十二種魔法同步 |
| 小怪與 Boss | 伺服器維持唯一血量、AI、快慢刀和階段，會尋找活著的玩家 |
| 傷害 | 合作 PvE；玩家攻擊傷害怪物，敵人範圍技可同時擊中多位玩家 |
| 背包與狀態 | 每人各自的生命、體力、魔力、冷卻、補給、金幣、草藥、武器強化與任務 |
| 商人與工匠 | 必須走近正確 NPC；伺服器檢查價格、材料與上限 |
| 採集 | 草藥先採先得，同一株不會重複給兩人；90 秒後重生 |
| 怪物重生 | 小怪 90 秒，Boss 600 秒；世界不停服便持續計時 |
| 曦光碑 | 只恢復使用者、更新個人復活點，不會重置其他人的戰鬥 |
| 死亡 | 扣本人 15% 金幣，3 秒後可復活；其他人繼續冒險 |
| 戰鬥獎勵 | 擊殺時附近 45 公尺內的存活玩家各自獲得報酬 |
| 選單 | 地圖、手記、魔法書、對話及 Esc 選單都不暫停世界 |
| 晚加入／離線 | 新玩家取得完整世界狀態；離開只移除該玩家 |

**目前角色是訪客角色，離線後個人聯機背包與任務不保留。** 每次加入從初始補給開始。尚未實作帳號、登入、角色資料庫或斷線續接；這些是長期經營世界需要的後續工作。

世界另存於伺服器的 `user://realm-world.json`，保存 Boss 擊敗紀錄及怪物、草藥的重生期限，每 10 秒和正常離開時寫入。伺服器重開會恢復這些期限；未死亡敵人的位置與剩餘血量不持久保存。單人 `aurelia_save.json` 完全分開，聯機收益不會寫進單人存檔。

## 同步方式與限制

- 伺服器執行物理、命中、傷害、AI、消耗、交易和獎勵。客戶端只送移動方向與動作請求，無法直接指定座標、金幣或傷害。
- 客戶端僅與伺服器交換遊戲訊息，關閉客戶端之間的 RPC 轉送；玩家列表由伺服器快照提供。
- 方向長度、有限數值、動作序號、技能索引、NPC 距離、鎖定距離與視線均有檢查。動作請求限速，重播序號不會再次消耗或發獎勵。
- 預設物理 60 Hz，世界快照目標 20 Hz。每份快照壓縮後分成不超過 1,000 bytes 的片段，再由客戶端組合；缺片的快照捨棄，下一份完整快照可恢復。實際更新頻率受主機負載影響。
- 玩家位置以插值顯示；尚未加入本機預測、延遲補償或區域可見性裁切。高延遲環境的手感仍需優化。
- 32 個客戶端測試驗證入服、成員同步和滿員拒絕；**不代表已完成 32 人同時放大型法術的效能、長時間穩定性或公網安全壓測**。

## 重現驗證

```sh
python3 tools/test_network.py
python3 tools/test_capacity.py
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/network_host.gd
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/snapshot.gd
python3 tools/capture_network.py
```

測試使用 24671–24674 的本機 UDP 連接埠，關閉測試世界的正式存檔寫入，結束後清理自己啟動的程序。容量測試包含 32 個輕量 Godot 客戶端及第 33 個滿員測試。實機擷取使用獨立伺服器、一個原生渲染客戶端和另一個無視窗遊戲客戶端，以固定站位、鏡頭及測試無敵時間展示共同 Boss 戰；不改使用者存檔。

畫面在 `screenshots/multiplayer-menu.png`、`multiplayer-coop.png` 和 `multiplayer-boss.png`，詳細紀錄見 `tests/VERIFICATION.md`。
