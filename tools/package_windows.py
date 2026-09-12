"""Package an already exported Windows release, including instructions and licenses."""
import hashlib,shutil,struct,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
release=ROOT/'builds/Aurelia-Windows'
exe=release/'Aurelia.exe'
pack=release/'Aurelia.pck'
with exe.open('rb') as f:
    assert f.read(2)==b'MZ','Missing Windows executable header'
    f.seek(0x3c)
    offset=struct.unpack('<I',f.read(4))[0]
    f.seek(offset)
    assert f.read(4)==b'PE\0\0' and struct.unpack('<H',f.read(2))[0]==0x8664,'Expected x86-64 Windows PE'
assert pack.stat().st_size>1000000,'Missing game resource pack'

instructions='''曦光之境 · AURELIA — Windows 64 位元朋友測試版

開始遊戲
1. 先將整個 ZIP「全部解壓縮」，不要直接在 ZIP 裡執行。
2. 打開 Aurelia-Windows 資料夾，雙擊 Aurelia.exe。
3. Aurelia.pck 必須留在同一資料夾；不需要安裝 Godot 或 Blender。

多人聯機
選「多人聯機 · 共同世界」，填自己的角色名稱、開服者給你的伺服器 IP 和連接埠 24567。
不在同一個網路時，請使用開服者提供的公網位址。127.0.0.1 只會連到你自己的電腦。
開服者必須先開啟伺服器並完成外網設定。收到遊戲包並不代表伺服器已上線。
所有玩家須使用相同遊戲版本。最多 32 人，共同探索、打怪與挑戰 Boss。
聯機選單不會暫停世界。目前為訪客角色，離線後個人聯機等級、背包與任務不保留。

操作
WASD 移動；滑鼠轉視角；Shift 奔跑；Space 翻滾。
滑鼠左鍵三連劍擊；右鍵重擊；Q 鎖定；H 騎馬。
Tab 切換術式組；1–4 施放魔法；R 補血；E 互動。
K 魔法書；M 地圖；J 手記；Esc 選單。

啟動遇到顯示問題
正常模式使用 Forward+。若顯示卡無法啟動，可試 Aurelia-Compatibility.bat；此模式畫面效果可能有所不同。
這是尚未簽署的朋友測試版，尚未在實際 Windows 電腦完成顯示卡相容性驗證。
若失敗，請把錯誤畫面及顯示卡型號提供給開發者；不需要關閉防毒軟體。

版本：0.6.0 — 2026-09-13；Godot 4.6，Windows x86-64。
等級系統：1–50 級，擊殺獲得經驗，依職業成長生命、魔力與傷害。單人自動存檔。
緊湊地圖版：2.4 × 2.4 公里分區世界、72 個新增聚落、19 座區域地城，共 20 隻 Boss。
主聚落間距約 440 公尺，新增 32 個路邊營地／遺跡、32 隻小怪與 64 處草藥。
開始前可選性別、五種職業與四種優先技能。M 切換地圖，靠近曦光碑可用驛站旅行。
最終 Boss 為三階段天穹古龍。此版與舊版聯機協定不相容，朋友和伺服器都要更新。
遊戲中包含的第三方授權見 LICENSES 資料夾。
'''
(release/'開始遊戲與聯機說明.txt').write_text(instructions,encoding='utf-8-sig')
(release/'Aurelia-Compatibility.bat').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nstart "" "%~dp0Aurelia.exe" --rendering-method gl_compatibility\r\n')
licenses=release/'LICENSES'
licenses.mkdir(exist_ok=True)
for source,name in [
    (ROOT/'tools/export_templates/4.6.stable/GODOT-LICENSE.txt','GODOT-LICENSE.txt'),
    (ROOT/'tools/export_templates/4.6.stable/GODOT-COPYRIGHT.txt','GODOT-COPYRIGHT.txt'),
    (ROOT/'assets/fonts/OFL.txt','NOTO-OFL.txt'),
    (ROOT/'art/vendor/LICENSES.md','CHARACTERS.md'),
]:shutil.copyfile(source,licenses/name)
(licenses/'FONT-SOURCE.txt').write_text('Noto Sans CJK TC Regular — SIL Open Font License 1.1\nhttps://github.com/notofonts/noto-cjk/tree/main/Sans\n')
for source in (ROOT/'assets/vendor').rglob('*'):
    if source.is_file() and (source.suffix in ['.txt','.md'] or source.name=='sources.json'):
        target=licenses/'PUBLIC-ASSETS'/source.relative_to(ROOT/'assets/vendor')
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
archive=ROOT/'builds/Aurelia-Windows.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for path in sorted(release.rglob('*')):
        if path.is_file():z.write(path,path.relative_to(release.parent))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None,'Archive integrity check failed'
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(digest+'  '+archive.name+'\n')
print(f'WINDOWS PACKAGE: {archive} ({archive.stat().st_size/1024/1024:.1f} MiB)')
print('PE x86-64 header, companion PCK and ZIP integrity verified.')
