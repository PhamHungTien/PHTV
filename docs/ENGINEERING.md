# Bảo trì kỹ thuật PHTV

Tài liệu này ghi những quality gate có thể kiểm chứng từ repository và giới hạn
nợ kỹ thuật. Nó không thay thế [kiến trúc](ARCHITECTURE.md) hay
[quy trình kiểm thử](TESTING.md).

## Quality gates

| Phạm vi | Pull request | Nightly | Release |
| --- | --- | --- | --- |
| Metadata, privacy manifest, appcast | Bắt buộc | — | Bắt buộc |
| Dictionary source và generated binary | Bắt buộc | — | Bắt buộc |
| Debug build | Bắt buộc | — | — |
| Toàn bộ XCTest | Bắt buộc, không retry | Thread Sanitizer | Bắt buộc, không retry |
| Static analysis | Khi cần tại local | Bắt buộc | Khuyến nghị local trước tag |
| Developer ID, notarization, Sparkle signature | — | — | Bắt buộc |

## Ngân sách nợ kỹ thuật

Các giới hạn sau nằm trong `scripts/tests/test_repository_policy.py` và chỉ được
phép đi xuống:

- tối đa **364** lời gọi `NSLog` cũ; code mới dùng `PHTVLogger`/`os.Logger` và
  không ghi dữ liệu do người dùng cung cấp;
- tối đa **36** khai báo `@unchecked Sendable`; mọi mutable state trong nhóm này
  phải được bảo vệ bởi cùng một lock hoặc executor;
- **0** `nonisolated(unsafe)`;
- mọi GitHub Action bên ngoài phải pin full commit SHA;
- không có link tài liệu local bị hỏng.

Các con số là trần chống hồi quy, không phải mục tiêu cuối. Khi sửa một khu vực,
nên chuyển log cũ sang category phù hợp và thay `@unchecked Sendable` bằng actor,
immutable value hoặc type Sendable thực sự nếu không ảnh hưởng hot path.

## File lớn và ranh giới module

Không tách file chỉ để giảm số dòng. Ưu tiên refactor khi có test hành vi và một
ranh giới rõ:

1. pure decision/policy type có input-output xác định;
2. service sở hữu một tài nguyên như event tap, AX cache hoặc panel;
3. view section độc lập chỉ nhận state/action cần thiết;
4. dataset generated tách khỏi logic runtime.

Các file hot path như engine, event callback và hotkey phải được chia theo hành
vi, giữ allocation/lock ngoài đường xử lý phím và benchmark lại latency.

## Dependency và dịch vụ mạng

- Commit lockfile cùng thay đổi dependency.
- Review release notes/license và chạy full suite trước khi nâng Sparkle.
- Cập nhật `THIRD_PARTY_NOTICES.md`, `docs/PRIVACY.md` và privacy manifest trước
  khi thêm endpoint, SDK hoặc data collection.
- Public client identifier trong app không được mô tả như secret. Secret dùng để
  ký/notarize chỉ nằm trong GitHub environment/repository secrets.

## Rà soát định kỳ

Mỗi minor release nên kiểm tra dependency, tài liệu tương thích và privacy. Mỗi
major release nên rà lại entitlement, deployment target, supported macOS matrix,
toàn bộ `@unchecked Sendable` và khả năng phục hồi từ bản public trước qua Sparkle.
