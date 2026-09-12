# 第三方角色、服裝與動作來源

取得日期：2026-09-05–06。以下實際使用的素材均為作者公開提供的 **CC0 1.0** 版本，可修改並用於商業專案。原始下載與 SHA-256 見 `downloads.json`；本目錄不由 Godot 匯入，也不屬於遊戲執行資源。

| 素材／作者 | 官方來源及授權依據 | 遊戲中的使用與修改 |
| --- | --- | --- |
| HairSample Male / pixiv VRoid Project | [pixiv 樣本授權說明](https://vroid.pixiv.help/hc/en-us/articles/4402614652569-Do-VRoid-Studio-s-sample-models-come-with-conditions-of-use)、[下載鏡像](https://opengameart.org/content/vroid-studio-cc0-models) | 主角、男性村民、守誓者的動漫臉部及髮型。移除現代帽衫與身體，重新配接奇幻服裝骨架；守誓者髮色改為銀藍。 |
| Vivi，舊版 AvatarSample 2 / pixiv VRoid Project | [作者的 CC0 聲明](https://vroid.pixiv.help/hc/en-us/articles/360014900273-%CE%B2-Ver-AvatarSample-2) | 烹飪師、麵包學徒、藥草師。保留原始臉部、衣服刺繡和透明貼圖，重定向站姿與交談動作，另加廚師帽。 |
| Victoria，舊版 AvatarSample 4 / pixiv VRoid Project | [作者的 CC0 聲明](https://vroid.pixiv.help/hc/en-us/articles/360014900233-%CE%B2-Ver-AvatarSample-4) | 村長、星術導師、學者。保留裙裝、髮型及面部貼圖，重定向全身站姿與交談動作。 |
| Modular Character Outfits – Fantasy **Standard 免費版** / Quaternius | [作者介紹與 CC0 說明](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html)、[正式下載頁](https://quaternius.itch.io/modular-character-outfits-fantasy)、壓縮檔內 `License_Standard.txt` | Male Ranger 服裝用於主角、衛隊長、Boss；Male Peasant 用於男性村民。重新搭配動漫頭部、脖頸、武器插槽，Boss 加上本專案製作的胸甲、冠飾、日冕。免費包的四套完整服裝已足夠本次使用，沒有取得付費 Source 檔案。 |
| Universal Animation Library **Standard** / Quaternius | [作者頁](https://quaternius.com/packs/universalanimationlibrary.html)、[作者的下載頁](https://opengameart.org/content/universal-animation-library)、壓縮檔內 License.txt | 劍士待機、重斬、翻滾、行走、奔跑、衝刺、施法、受擊、坐姿、交談。於 Blender 做不同身形骨架的旋轉與骨盆高度重定向。 |
| Universal Animation Library 2 **Standard** / Quaternius | [作者頁](https://quaternius.itch.io/universal-animation-library-2)、[作者的下載頁](https://opengameart.org/content/universal-animation-library-2)、壓縮檔內 License.txt | 三段劍擊與回收、格擋動作。遊戲重新設定連段、速度、前搖、恢復和命中時點。 |

VRoid 鏡像中的 `AvatarSample_E`、`AvatarSample_G` 是上述 **舊版 beta Vivi / Victoria**，並非現行同字母的新樣本。兩個舊 VRM 的內嵌 `licenseName` 是 `Other`，同時附上允許修改、商用和再散布的授權網址；此處的 CC0 依據是 pixiv 對具名舊樣本的官方公開聲明。沒有將所有 VRoid 樣本一概視為同一授權。

另曾下載 [Dawn to Dusk Games 的 CC0 Anime Female Mage](https://dawn-to-dusk-games.itch.io/3d-anime-female-mage-character) 免費 GLB/FBX 供造型比對，**本次未整合至執行資源**；未下載付費 Blender Source 版本。

本專案的改編不表示素材作者參與、背書本遊戲。沒有使用《原神》、《崩壞：星穹鐵道》或《艾爾登法環》的拆包模型、角色設計或動畫。

## 重建

1. 將 `downloads.json` 所列素材解壓至對應子目錄；保留 VRM 原檔並建立同內容 `.glb` 副本，讓 Blender 的 glTF 匯入器讀取。
2. `Blender --background --factory-startup --python art/build_template_characters.py`
3. `python3 tools/optimize_characters.py`（需要 `tools/npm-cache` 內的 glTF Transform CLI 4.3.0；首次使用見該腳本）。
4. Godot `--headless --editor --path . --import --quit`。

產物為 `art/blender/*_rigged.blend` 與 `assets/models/*_rigged.glb`。GLB 保留蒙皮、動作、臉部 morph targets、透明貼圖；去除重複與未使用資料，不使用 Draco 或 Meshopt 壓縮。執行期武器使用手骨的 BoneAttachment3D，角色的水平位移由 CharacterBody3D 處理，避免動畫根位移重複套用。
