# Blender 美術來源

這些是遊戲中實際使用的模型，並非概念圖。`blender/` 保留可編輯的 Blender 5.2 原始檔；`../assets/models/` 是輸出給 Godot 的 GLB。

## 本次網路模板修訂

主角、Boss 和 NPC 的現行執行資源是 `*_rigged.glb`，原始檔為 `blender/*_rigged.blend`。由 `build_template_characters.py` 整合 CC0 的 VRoid 角色與 Quaternius 奇幻服裝、動作庫。完整來源和重建方式見 [vendor/LICENSES.md](vendor/LICENSES.md)。舊版 `traveler.blend` 等保留為早期原創造型參考，不再代表目前的主角與 Boss。

主角及 Boss 各有 17 個骨架動畫片段，三種村民資產各有 4 個。骨架重定向保留關節旋轉、骨盆上下移動與原模型比例；執行期以 BoneAttachment3D 配接武器，臉部透明貼圖不套用舊版不支援 alpha 的卡通材質。`tools/optimize_characters.py` 執行 glTF Transform dedup/prune；結果記錄於 `character-optimization.json`。

## 早期原創模型重新建立

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/build_assets.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/build_anime_characters.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/build_scene.py
```

`build_assets.py` 包含原始建模步驟：輪廓放樣、曲面盔甲、披風褶皺、頭部細節、分片屋瓦、砌石拱門、樹枝與折葉、馬匹和鞍具。合併相同關節及材質的網格後輸出，保留遊戲動畫所需的關節節點。單位為公尺，GLB 使用 Y 軸朝上、-Z 為前方。

`build_anime_characters.py` 將主角、村民、守誓者與野外敵人替換為原創動漫人物。杏仁形眼白、虹膜高光、睫毛、尖下巴、分束頭髮、耳飾、合身外套、金邊衣襬和長靴均為實際網格。保留原有關節名稱以支援遊戲動作。

`build_scene.py` 製作噴泉、盾牌與雕飾石柱，並用資產集合實例組裝 `aurelia_village.blend`。請依上面的順序執行；只執行基礎腳本會恢復舊版角色。

## 主要原始檔

- `blender/traveler.blend`：銀白髮旅行劍士、青綠挑染、大眼睛、象牙色外套與披風。
- `blender/sunwarden.blend`：金瞳守誓者、長髮、浮空太陽冠、酒紅色服裝。
- `blender/villager.blend`：棕髮馬尾村民，可由遊戲調整服裝配色。
- `blender/field_enemy.blend`：深色髮型、金色眼睛與深藍戰鬥服的野外敵人。
- `blender/horse.blend`：馬匹、鬃毛、韁繩、馬鞍、馬鐙與鞍袋。
- `blender/cottage.blend`：石木民宅、拱門、百葉窗、花箱、逐片屋瓦。
- `blender/castle_tower.blend`、`castle_gate.blend`：城堡砌石、箭窗、城垛、拱門和旗幟。
- `blender/golden_oak.blend`、`blossom_tree.blend`、`pine_tree.blend`：枝幹與葉片模型。

`render_assets.py` 以 Cycles 渲染實際模型供檢查。遊戲使用動態光照；靜態網格在世界建立後批次繪製，Godot 匯入時產生網格 LOD。

Godot 角色使用 `shaders/anime.gdshader` 分段明暗與獨立臉部光照，以及 `anime_outline.gdshader` 輪廓描邊。`tests/character_review.gd` 直接載入遊戲 GLB 與相同材質，輸出 `screenshots/anime-lineup.png` 和 `anime-portrait.png`；這兩張是引擎渲染，沒有使用概念圖代替模型。

這是第一版自製模型；角色動畫使用階層關節驅動，尚不是動作捕捉或完整蒙皮動畫，披風也尚未做物理布料模擬。
