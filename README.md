# Lái Xe 3D

Game lái ô tô góc nhìn thứ nhất (Godot 4.7.2, GL Compatibility) cho Android.

- **Thi sa hình B**: 11 bài, chấm điểm tự động (100 điểm, đạt ≥ 80), có tình huống bất ngờ; luyện riêng từng bài.
- **Lái tự do**: thành phố có xe AI, đèn giao thông; ngày/đêm, nắng/mưa; ghi lỗi vi phạm.
- **Nhiệm vụ**: 9 màn đỗ xe, đỗ song song, chở khách, giao hàng.
- **Garage**: 6 mẫu xe, 8 màu sơn. **Cài đặt**: vô lăng / nghiêng máy / nút, số tự động / số sàn, đồ họa, âm lượng, gương.
- Tiếng Việt / English. Toàn bộ âm thanh được tạo bằng code.

## Build

GitHub Actions (`.github/workflows/build.yml`) tự build mỗi lần đẩy code lên `main`:
APK (cài thử) và AAB (Google Play), targetSdk/compileSdk 36, minSdk 24.

Secrets cần có trong repo (Settings → Secrets and variables → Actions):

| Tên | Nội dung |
|---|---|
| `KEYSTORE_BASE64` | file keystore mã hóa base64 |
| `KEYSTORE_PASSWORD` | mật khẩu keystore (Godot dùng chung cho cả key) |
| `KEY_ALIAS` | alias của key |

Chưa có Secrets thì workflow dùng khóa tạm: APK vẫn cài thử được nhưng AAB không dùng lên Play.

## Điều khiển trên máy tính (khi chạy thử trong Godot)

Mũi tên / WASD: lái, ga, phanh · Q/E: xi nhan · H: khẩn cấp · 1-4: P R N D · Shift: côn · PgUp/PgDn: lên/xuống số · K: đề · C: đổi camera · L: đèn · B: dây an toàn · Space: phanh tay · Esc: tạm dừng.
