function tests = test_dataset
%TEST_DATASET Test trên bộ dữ liệu data/wav do scripts/make_dataset sinh ra.
%   Mỗi tệp đi đúng đường của nút "Mở tệp âm thanh…" là dtmf_readaudio rồi
%   dtmf_run, với cả ba phương pháp. Kỳ vọng của từng tệp nằm ở cột kyVong của
%   data/wav/manifest.csv, nên thêm tệp vào make_dataset là thêm ca test.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Giải mã mỗi tệp một lần cho cả ba phương pháp, các ca sau chỉ đọc kết quả.
root = fileparts(fileparts(mfilename('fullpath')));
f = fullfile(root, 'data', 'wav', 'manifest.csv');
testCase.assumeTrue(isfile(f), ...
    'Chưa có data/wav/manifest.csv, chạy addpath(''scripts''); make_dataset trước.');

M  = docManifest(f);
pp = phuongPhap();
K  = cell(height(M), numel(pp));
L  = cell(height(M), numel(pp));
A  = nan(height(M), numel(pp));
for i = 1:height(M)
    x = dtmf_readaudio(fullfile(root, 'data', 'wav', M.tep{i}));
    for j = 1:numel(pp)
        S = dtmf_run(struct('y', x, 'fs', 8000, 'method', pp{j}));
        K{i, j} = S.keysHat;
        L{i, j} = S.lastError;
        if ~isempty(M.phim{i})
            m = dtmf_metrics(M.phim{i}, S.keysHat);
            A(i, j) = m.acc;
        end
    end
end
testCase.TestData.root = root;
testCase.TestData.M = M;
testCase.TestData.K = K;
testCase.TestData.L = L;
testCase.TestData.A = A;
end

% ------------------------------------------------------------- bảng nhãn

function test_manifestMatchesFilesOnDisk(testCase)
% Mọi tệp âm thanh trong data/wav đều có nhãn và ngược lại. Tệp thả vào mà
% không qua make_dataset sẽ không được test nào đụng tới, nên phải đỏ ở đây.
M = testCase.TestData.M;
wavDir = fullfile(testCase.TestData.root, 'data', 'wav');
d = [dir(fullfile(wavDir, '**', '*.wav')); dir(fullfile(wavDir, '**', '*.flac'))];
tuongDoi = cellfun(@(p) strrep(p(numel(wavDir)+2:end), '\', '/'), ...
    fullfile({d.folder}, {d.name}), 'UniformOutput', false);
testCase.verifyEqual(sort(tuongDoi(:)), sort(M.tep));

for i = 1:height(M)
    info = audioinfo(fullfile(wavDir, M.tep{i}));
    testCase.verifyEqual(info.SampleRate, M.fs(i), M.tep{i});
    testCase.verifyEqual(info.NumChannels, M.kenh(i), M.tep{i});
end
end

function test_manifestLabelsAreValid(testCase)
% Nhãn sai chính tả làm một tệp rơi khỏi mọi nhánh kiểm, nên chặn ở đây.
M  = testCase.TestData.M;
T  = dtmf_table();
pp = phuongPhap();
for i = 1:height(M)
    testCase.verifyTrue(all(ismember(M.phim{i}, T.keys(:))), M.tep{i});
    testCase.verifyTrue(ismember(M.kyVong{i}, {'dung', 'rong', 'thong_ke'}), M.tep{i});
    testCase.verifyTrue(all(ismember(ngoaiLe(M, i), pp)), M.tep{i});
end
% Số điện thoại phải giữ số 0 đầu khi qua CSV.
testCase.verifyEqual(M.phim{strcmp(M.tep, 'sach/so_dt_01.wav')}(1), '0');
end

% ------------------------------------------------------------- từng tệp

function test_noFileRaisesDecodeError(testCase)
% dtmf_run không ném lỗi mà ghi vào lastError, nên phải đọc trường đó.
L = testCase.TestData.L;
M = testCase.TestData.M;
pp = phuongPhap();
for i = 1:height(M)
    for j = 1:numel(pp)
        testCase.verifyEmpty(L{i, j}, sprintf('%s qua %s', M.tep{i}, pp{j}));
    end
end
end

function test_dungFilesDecodeExactly(testCase)
% Tệp nhãn 'dung' là điều kiện dự án cam kết (sạch, SNR >= 10 dB, twist trong
% giới hạn, nhịp >= 100/50 ms, mọi định dạng tệp) nên phải đúng từng phím.
kiemKyVong(testCase, 'dung');
end

function test_rongFilesStaySilent(testCase)
% Tệp nhãn 'rong' không có phím hợp lệ nào, bộ giải mã phải im lặng.
kiemKyVong(testCase, 'rong');
end

function test_knownExceptionsStillHold(testCase)
% Ngoại lệ ghi trong cột ngoaiLe phải còn đúng. Bộ giải mã nào đã hết sai
% trên tệp đó thì ca này đỏ, nhắc xóa ngoại lệ trong make_dataset để nhãn và
% CONTRACTS §7.13 không nói một điều đã hết đúng.
M  = testCase.TestData.M;
K  = testCase.TestData.K;
pp = phuongPhap();
for i = find(~cellfun(@isempty, M.ngoaiLe)).'
    for j = find(ismember(pp, ngoaiLe(M, i)))
        testCase.verifyFalse(datKyVong(K{i, j}, M.phim{i}, M.kyVong{i}), ...
            sprintf(['%s qua %s đã đạt kỳ vọng ''%s'', xóa ngoại lệ trong ' ...
                     'make_dataset rồi sinh lại.'], M.tep{i}, pp{j}, M.kyVong{i}));
    end
end
end

% ------------------------------------------------------------- thống kê

function test_accuracyFallsAsSnrDrops(testCase)
% Ở mỗi loại nhiễu, độ chính xác trung bình không tăng khi SNR giảm, và mức
% thấp nhất thật sự khó. Nếu dtmf_addnoise cộng sai mức thì ca này đỏ.
for nhom = {'awgn', 'hum50', 'speech'}
    [snr, acc] = chinhXacTheoSnr(testCase, nhom{1});    % snr giảm dần
    testCase.verifyTrue(all(diff(acc) <= 0, 'all'), ...
        sprintf('%s: độ chính xác tăng khi SNR giảm', nhom{1}));
    testCase.verifyLessThan(mean(acc(end, :)), 1, ...
        sprintf('%s ở %g dB: cả ba bộ giải mã vẫn đúng hết', nhom{1}, snr(end)));
end
end

function test_filterbankMostRobust(testCase)
% Kết quả chính của đề tài: ở mọi mức SNR của cả ba loại nhiễu, ngân hàng
% bộ lọc đúng ít nhất bằng FFT và Goertzel.
for nhom = {'awgn', 'hum50', 'speech'}
    [snr, acc] = chinhXacTheoSnr(testCase, nhom{1});
    for s = 1:numel(snr)
        testCase.verifyGreaterThanOrEqual(acc(s, 3), max(acc(s, 1:2)), ...
            sprintf('%s ở %g dB', nhom{1}, snr(s)));
    end
end
end

function test_humAt2p5dbSplitsFftFromFilterbank(testCase)
% README: với nhiễu điện lưới 50 Hz, ngân hàng bộ lọc đúng hết từ 2.5 dB trong khi FFT
% gần như mất hết, vì FFT lấy năng lượng khung thô làm mẫu số.
[snr, acc] = chinhXacTheoSnr(testCase, 'hum50');
s = snr == 2.5;
testCase.verifyEqual(acc(s, 3), 1);
testCase.verifyLessThan(acc(s, 1), 0.5);
end

% ------------------------------------------------------------- tái lập

function test_datasetIsUpToDate(testCase)
% Sinh lại vào thư mục tạm rồi so từng mẫu với data/wav. Sửa dtmf_generate,
% dtmf_addnoise hay make_dataset mà quên sinh lại thì ca này đỏ. So mẫu chứ
% không so byte để khác biệt siêu dữ liệu của bộ mã FLAC không làm đỏ oan.
root = testCase.TestData.root;
addpath(fullfile(root, 'scripts'));
trangThai = rng;
testCase.addTeardown(@() rng(trangThai));
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
evalc('make_dataset(tmp);');

wavDir = fullfile(root, 'data', 'wav');
testCase.verifyEqual(fileread(fullfile(tmp, 'manifest.csv')), ...
    fileread(fullfile(wavDir, 'manifest.csv')), ...
    'manifest.csv đã cũ, chạy lại make_dataset().');
M = testCase.TestData.M;
for i = 1:height(M)
    [a, fa] = audioread(fullfile(tmp, M.tep{i}), 'native');
    [b, fb] = audioread(fullfile(wavDir, M.tep{i}), 'native');
    testCase.verifyTrue(isequal(a, b) && fa == fb, ...
        sprintf('%s đã cũ, chạy lại make_dataset().', M.tep{i}));
end
end

% ------------------------------------------------------------- hàm phụ

function pp = phuongPhap()
pp = {'fft', 'goertzel', 'filterbank'};
end

function M = docManifest(f)
% Ép các cột chữ về char, nếu không readtable đọc số điện thoại thành số và
% mất số 0 đầu.
o = detectImportOptions(f, 'Encoding', 'UTF-8', 'Delimiter', ',');
o = setvartype(o, {'tep', 'nhom', 'phim', 'kyVong', 'ngoaiLe', 'nhieu', 'ghiChu'}, 'char');
M = readtable(f, o);
end

function n = ngoaiLe(M, i)
% Tên các bộ giải mã được miễn kỳ vọng ở dòng i, cách nhau bởi dấu cách.
n = strsplit(strtrim(M.ngoaiLe{i}));
n = n(~cellfun(@isempty, n));
end

function ok = datKyVong(keysHat, phim, kyVong)
switch kyVong
    case 'dung'
        ok = strcmp(keysHat, phim);
    case 'rong'
        ok = isempty(keysHat);
    otherwise
        ok = true;
end
end

function kiemKyVong(testCase, kyVong)
% Mọi tệp có nhãn kyVong, mọi bộ giải mã không nằm trong ngoaiLe.
M  = testCase.TestData.M;
K  = testCase.TestData.K;
pp = phuongPhap();
idx = find(strcmp(M.kyVong, kyVong)).';
testCase.assertNotEmpty(idx);
for i = idx
    for j = find(~ismember(pp, ngoaiLe(M, i)))
        testCase.verifyTrue(datKyVong(K{i, j}, M.phim{i}, kyVong), ...
            sprintf('%s qua %s: cần ''%s'', đọc được ''%s''', ...
                    M.tep{i}, pp{j}, M.phim{i}, K{i, j}));
    end
end
end

function [snr, acc] = chinhXacTheoSnr(testCase, nhom)
% Độ chính xác trung bình theo mức SNR của một nhóm nhiễu, SNR giảm dần.
% acc là nSnr×3, cột theo phuongPhap().
M = testCase.TestData.M;
A = testCase.TestData.A;
o = strcmp(M.nhom, nhom);
snr = sort(unique(M.snrDb(o)), 'descend');
acc = zeros(numel(snr), size(A, 2));
for s = 1:numel(snr)
    acc(s, :) = mean(A(o & M.snrDb == snr(s), :), 1);
end
end
