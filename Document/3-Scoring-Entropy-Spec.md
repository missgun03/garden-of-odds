# Scoring & Entropy Spec (Short)

**EventScoreᵢ = Pᵢ × Lᵢ × C**

- `Pᵢ` = แต้มฐานพืช/เหตุการณ์ (ดูใน data/plants)
- `Lᵢ` = ตัวคูณเฉพาะตำแหน่ง/เพื่อนบ้าน/สถานะ
- `C` = ตัวคูณความยาวเชน = `1 + α·ln(1 + ChainLen)` (α≈0.8)

**PhaseTotal = Σ EventScore × (M_set × M_mut × M_biome × M_entropy)**

- `M_set` = ชุด/แท็ก (เช่น Fungus Trio)
- `M_mut` = Mutation ที่ active
- `M_biome` = ตัวคูณไบโอม
- `M_entropy` = `1 + β·Entropy^γ` (β≈0.02, γ≈0.8) พร้อม softcap ~7×
- `E_cap` (Grove) = 100; แตะ/เกิน = Collapse

**Entropy Gains (ตัวอย่าง)**
- ระเบิด/แตกหน่อ: +1.0
- เชนคอนติวนิว: +0.2/เหตุการณ์ถัดไป
- บัฟซ้อนในรอบเดียว: +0.3/สแตก
- มิเรอร์/สะท้อน: +0.1/ครั้ง (cap ต่อเฟส)

**Order of Ops**
1) Resolve per-event → บวก Entropy ตาม rule
2) รวม PhaseBase
3) คูณ multipliers → PhaseTotal
4) เช็ก Collapse
