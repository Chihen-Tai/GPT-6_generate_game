# 五區公開素材擴充（0.3.0）

本版使用作者已完成的模型、骨架、動畫及貼圖，Blender 僅用於轉檔、材質修復與動作重定向。新增美術沒有從零建立模型。戰鬥判定、碰撞、地形承載網格與特效運動軌跡仍由遊戲程式控制。

## 素材來源

| 作者／素材包 | 模型數 | 來源與授權 |
|---|---:|---|
| KayKit Medieval Hexagon | 221 | https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0 · CC0 |
| KayKit Dungeon Remastered | 203 | https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 · CC0 |
| KayKit Adventurers | 32 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 · CC0 |
| KayKit Skeletons | 17 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 · CC0 |
| Quaternius Animated Monsters | 4 | https://opengameart.org/content/lowpoly-animated-monsters · CC0 |
| Quaternius Farm Animals | 7 | https://opengameart.org/content/lowpoly-animated-farm-animal-pack · CC0 |
| Kenney Particle Pack | 80 款圖案，附背景／旋轉變體 | https://kenney.nl/assets/particle-pack · CC0 |
| Poly Haven Grass Path 2 | 2 張 2K 地表貼圖 | https://polyhaven.com/a/grass_path_2 · Rob Tuytel · CC0 |

合計 484 個新下載模型存於素材庫。**素材庫數量不等於已擺進地圖的不同模型數**，實際使用清單和擺放次數由 `tests/world_review.gd` 產生於 `art/expansion-runtime.json`。模型、貼圖雜湊記錄於 `art/expansion-provenance.json`，原始下載保留於 `art/vendor/expansion`，正式執行素材在 `assets/vendor`。可免費商用、修改與隨遊戲散布；這個判斷只涵蓋表列且附授權的實際素材，並非所有網路公開模型。

本批環境、怪物與新配角為風格化低多邊形素材；動漫主角與原有 VRoid NPC 保留。這不是《原神》等級的高精度角色／場景製作，新增 KayKit 配角比例也較 Q 版。

## 五區內容

- 晨鐘平原：藍頂村落、風車、鐵匠、市場、餐桌、馬廄與商旅行裝。
- 鏡露森林：加密樹群、綠頂聚落、湖水與水生植物、晶凍與蝙蝠。
- 曦白王城：城堡、雙塔、住宅與商旅廣場、家具、兵器架。
- 霜冠高地：雪地、裂牆廢堡、礦場、骸骨軍團與重衛。
- 日冕聖域：石柱與拱廊圍成的戰場、古龍、場外補給 NPC 及休息碑。

陸地從約 224 × 244 公尺擴至 480 × 500 公尺；道路相連，可步行或騎馬探索。28 位可互動 NPC、42 隻野外敵人、1 位最終 Boss。四個新增區域均有休息／存檔碑。商人和工匠延用現有交易功能，尚無各區獨立任務線。

## 動作與 Boss

原有 NPC 使用 Quaternius 的 Interact、PickUp_Table、Dance_Loop 作為工匠操作、取物、樂師表演；新配角採用 KayKit 原始工作、施法、交談與警戒動作。坐騎改用具 Idle／Walk／Run 骨架動畫的公開馬匹。主角保留已重定向的完整揮劍與翻滾動畫。

天穹古龍・奧瑞利昂有 3400 HP：

1. 迅翼二連、遲暮龍爪、日蝕掃尾、天穹落印、日輪震波，混合快慢前搖與延遲連擊。
2. 生命低於 66%：加快節奏、追加連擊、三輪扇形星焰吐息。
3. 生命低於 30%：增加兩次落印的天穹審判，保留較長的施放前搖與恢復破綻。

未做玩家人數自動血量縮放；32 人圍攻的實際難度仍需朋友實測調整。場外脫戰會重置 Boss；重擊可打破架勢。

## 存檔與聯機

協定升至 `aurelia-realm-2`，舊 Windows 客戶端會收到版本不符提示。既有離線物品存檔可遷移，但舊 Boss 完成旗標不套用到新古龍。共享世界索引存檔升至版本 2，舊世界敵人／採集重生排程不讀入，避免誤套到擴充後的內容。埠號仍為 UDP 24567，8–32 人同一世界。

## 重建與檢查

- `tools/import_public_assets.py` 複製已下載 KayKit 和 Kenney 素材。
- `art/adapt_public_monsters.py`／`art/adapt_public_animals.py` 使用 Blender 轉存作者 .blend 與動畫。
- `art/build_template_characters.py` 更新原有 NPC 的現成動作重定向。
- `tests/expansion.gd` 檢查五區碰撞、人口、素材使用、動作、三階段、存檔與快照尺寸。
- `tests/world_review.gd` 以原生 Godot 產生五區畫面及執行時素材清單。

Windows 包以官方 Godot 4.6 x86-64 模板匯出；尚無本機 Windows 顯示卡實測環境。

## 本次驗證

- 原生 Godot 4.6 / Metal / Apple M4 實際渲染五個區域；已檢查材質、模型比例和場景畫面。
- 執行時擺入 **93 種不同公開模型、1116 個模型實例**（含建築、道具、植被、角色與坐騎）；其餘模型保留為素材庫。
- 遊玩 39、魔法 49、動作 31、五區新增檢查 24、聯機 51、主機狀態 13、快照 8：共 **215 項通過**。
- 32 個真實 Godot 客戶端均收到 32 位成員及至少五份快照，第 33 人被拒絕。這是連線容量驗證，尚非 32 人同時戰鬥的效能實測。

Windows 0.3.0 遊戲資源包額外通過 51 項聯機檢查，並以 Mac 原生引擎實際載入同一 PCK 渲染五區與終式魔法。Windows ZIP 約 199 MiB，包含 EXE、PCK、說明與素材授權。
