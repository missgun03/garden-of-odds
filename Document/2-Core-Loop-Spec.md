# Core Loop Spec — Garden of Odds

## Moment-to-Moment (หนึ่งเทิร์น)
Draft(3→1) → Place → Preview(Entropy Forecast) → Commit → Reaction Tick

- **Draft:** เลือก 1 จาก 3 เมล็ด (อิงกองของฤดู: Draft Stack)
- **Place:** วางบนกระดาน 5×5/7×7 (ตำแหน่งสำคัญ)
- **Preview:** แสดงคะแนนฐาน, Lᵢ, เอนโทรปีที่จะเพิ่ม, ปุ่ม Overgrow/Stabilize
- **Commit & Reaction:** รันเหตุการณ์และ chain แบบอ่านง่าย

## Season Structure (หนึ่งฤดู)
- มือที่ 1: วาง 2–3 ต้น → **Mini-Bloom** (0.8–1.0s)
- มือที่ 2: วาง 2–3 ต้น → **Bloom ใหญ่** (2–3s, breakdown)
- **Gate:** เช็กเป้าคะแนน → ผ่านสเตจหรือจบเกม
- **Interlude:** Trial หรือ Shop/Contracts ตามสูตร

## Draft Stack
- ต้นฤดู: สุ่มกอง 3x(3 ใบ) → เลือก 1 กอง (reroll กองได้ 1 ครั้ง/ฤดู)
- ระหว่างฤดู ดราฟท์จาก “กองที่เลือก” เท่านั้น

## Entropy Levers
- **Overgrow:** +Entropy +3 → เพิ่ม Lᵢ +0.3 และ +1 ChainLen สำหรับ event นี้
- **Stabilize:** ใช้ 10 coins ลด Entropy ปัจจุบัน -20% (1 ครั้ง/ฤดู)
- เอนโทรปีแบ่งระดับ: Low / Medium / High (เอฟเฟกต์ภาพ/เสียงต่างกัน)

## Pacing Targets
- 60–90s/ฤดู; 6 ฤดู = 12–18 นาที/รัน
