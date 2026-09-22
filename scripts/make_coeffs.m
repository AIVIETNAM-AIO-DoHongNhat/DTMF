%% make_coeffs.m
% MAKE_COEFFS Sinh data/mat/coeffs.mat - hệ số 14 bộ lọc cộng hưởng DTMF.
%
% Hệ số do CHÍNH design_bpf_bank dựng bằng công thức, KHÔNG phải do
% filterDesigner xuất ra (CONTRACTS.md §3): công thức cho phép dẫn giải được
% r = 0.99 và BW ≈ 25.5 Hz trong báo cáo, còn hệ số filterDesigner sinh ra là
% một dãy số không giải thích được khi vấn đáp.
%
% File lưu kèm siêu dữ liệu fs/r/withHarm để design_bpf_bank đối chiếu lúc nạp;
% lệch một trường là nó bỏ file và dựng lại - xem CONTRACTS.md §6(b).
%
% Cách dùng:  cd <repo>; addpath('scripts'); make_coeffs

clear;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));

fs       = 8000;
r        = 0.99;
withHarm = true;

% 'coeffs', '' ép design_bpf_bank đi nhánh CÔNG THỨC. Để mặc định thì nó nạp
% chính data/mat/coeffs.mat đang có, và việc sinh lại thành vô nghĩa: đổi r rồi
% chạy make_coeffs vẫn ra đúng file cũ.
bank = design_bpf_bank('fs', fs, 'r', r, 'withHarm', withHarm, 'coeffs', '');

% Kiểm TRƯỚC khi ghi. Một ngân hàng hỏng nằm được lên đĩa thì mọi lần chạy sau
% đều nạp nó vào im lặng, vì nhánh nạp chỉ đối chiếu siêu dữ liệu chứ không đo
% lại đáp ứng.
for j = 1:numel(bank)
    H = freqz(bank(j).b, bank(j).a, [bank(j).f bank(j).f], fs);
    assert(abs(abs(H(1)) - 1) < 1e-10, 'make_coeffs:gain', ...
        'Bo %d (%g Hz): |H(f0)| = %.12f, phai bang 1.', j, bank(j).f, abs(H(1)));
    assert(max(abs(roots(bank(j).a))) < 1, 'make_coeffs:unstable', ...
        'Bo %d (%g Hz): cuc nam ngoai vong tron don vi.', j, bank(j).f);
end

meta = struct('fs', fs, 'r', r, 'withHarm', withHarm);

outDir = fullfile(root, 'data', 'mat');
if ~isfolder(outDir)
    mkdir(outDir);
end
out = fullfile(outDir, 'coeffs.mat');
save(out, 'bank', 'meta');

fprintf('Da ghi %s (%d bytes)\n', out, dir(out).bytes);
fprintf('  %d bo loc | fs = %g Hz | r = %g | withHarm = %d\n', ...
    numel(bank), fs, r, withHarm);
fprintf('  tan so tam: %s Hz\n', num2str([bank.f]));
