function tests = test_table
%TEST_TABLE Unit test cho dtmf_table - bảng tần số và ánh xạ sang chỉ số bin.
%   Bảng sai thì các bộ giải mã vẫn chạy trơn tru nhưng ra kết quả sai.
tests = functiontests(localfunctions);
end


function dtmfFreqs = local_freqs()
% Bảy tần số chuẩn: 4 hàng rồi 3 cột.
T = dtmf_table();
dtmfFreqs = [T.rowHz, T.colHz];
end


function test_standardFrequencies(testCase)
% Tần số phải đúng ITU-T Q.23, không được làm tròn cho "đẹp".
T = dtmf_table();
testCase.verifyEqual(T.rowHz, [697 770 852 941]);
testCase.verifyEqual(T.colHz, [1209 1336 1477]);
end


function test_keyMapConsistent(testCase)
% T.map phải khớp T.keys ở cả 12 phím - bắt lỗi đảo nhầm hàng với cột.
T = dtmf_table();
testCase.verifyEqual(size(T.keys), [4 3]);
for r = 1:4
    for c = 1:3
        testCase.verifyEqual(T.map(T.keys(r, c)), [r c]);
    end
end
testCase.verifyEqual(T.map.Count, uint64(12));
end


function test_goertzelBins(testCase)
% Bảng bin chốt cho khung Goertzel N = 205 tại fs = 8000 Hz.
kG = round(205 * local_freqs() / 8000);
testCase.verifyEqual(kG, [18 20 22 24 31 34 38]);

% Bảy bin phải khác nhau, trùng bin là hai tần số hóa thành một.
testCase.verifyEqual(numel(unique(kG)), 7);
end


function test_fftBins(testCase)
% Bảng bin cho khung FFT đối chứng 256 điểm.
kF = round(256 * local_freqs() / 8000);
testCase.verifyEqual(kF, [22 25 27 30 39 43 47]);
testCase.verifyEqual(numel(unique(kF)), 7);
end


function test_binErrorWithinTolerance(testCase)
% Bin là số nguyên nên tâm bin lệch khỏi tần số chuẩn. Chỗ lệch nhất là
% 770 Hz (bin 20 -> 780.49 Hz, 1.36%), vẫn dưới dung sai ±1.5%.
F      = local_freqs();
fBin   = round(205 * F / 8000) * 8000 / 205;    % tần số tâm của bin
relErr = abs(fBin - F) ./ F * 100;              % [%]

testCase.verifyLessThan(max(relErr), 1.5);
testCase.verifyEqual(max(relErr), 1.362, 'AbsTol', 0.001);
end
