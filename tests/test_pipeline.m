function tests = test_pipeline
%TEST_PIPELINE Test đầu-cuối: sinh tín hiệu rồi giải mã lại, không mổ vào bên trong.
tests = functiontests(localfunctions);
end

function test_repeatedKeysNotSwallowed(testCase)
% Ca giá trị nhất cả bộ. '99' phải ra HAI ký tự: debounce gộp các khung liên
% tiếp cùng phím, nên hai lần bấm giống nhau chỉ tách ra được nhờ có ít nhất
% một khung bị loại trong khoảng lặng giữa chúng. Ở hop = 205 khoảng lặng
% KHÔNG chứa trọn khung nào (Study §11); khung xấu nhất chỉ 97.6% im lặng và
% ngưỡng mặc định vẫn loại được - nhưng đó là điều phải TEST, không phải tin.
keys = '12345699';
testCase.verifyEqual(dtmf_decode_goertzel(dtmf_generate(keys)), keys);
testCase.verifyEqual(numel(dtmf_decode_goertzel(dtmf_generate(keys))), 8);
end

function test_allTwelveKeys(testCase)
% Cả 12 phím, đi riêng lẻ và đi thành chuỗi. Sai bảng bin của một tần số nào
% đó thì chỉ vài phím hỏng, ca chuỗi ngắn dễ lọt qua.
T = dtmf_table();
allKeys = reshape(T.keys.', 1, []);          % '123456789*0#'

for i = 1:numel(allKeys)
    k = allKeys(i);
    testCase.verifyEqual(dtmf_decode_goertzel(dtmf_generate(k)), k, ...
        sprintf('phim %s', k));
end

testCase.verifyEqual(dtmf_decode_goertzel(dtmf_generate(allKeys)), allKeys);
end

function test_everyFrameGridAlignment(testCase)
% Quét CẠN mọi cách lưới khung căn lề so với biên tone, thay vì lấy mẫu vài
% chuỗi rồi hy vọng. Mỗi phím chiếm 1200 mẫu, khung nhảy 205 mẫu, mà
% gcd(1200, 205) = 5 nên vị trí tương đối lặp lại sau 205/5 = 41 phím: một
% chuỗi 41 phím đi qua đủ 41 kiểu căn lề. Một nửa số vị trí ép thành cặp lặp
% để ca này bao luôn bẫy nuốt phím ở mọi cách căn lề.
testCase.verifyEqual(gcd(1200, 205), 5);

T = dtmf_table();
allKeys = reshape(T.keys.', 1, []);
rng(1);
s = allKeys(randi(12, 1, 41));
s(2:2:end) = s(1:2:end-1);

testCase.verifyEqual(dtmf_decode_goertzel(dtmf_generate(s)), s);
end

function test_survivesNoiseAtDemoLevel(testCase)
% CONTRACTS.md dặn demo ở SNR >= 10 dB. Ca này ghim lời dặn đó: ở đúng 10 dB
% phải đọc đúng tuyệt đối. Nếu ai siết energyRatio hay đổi chuẩn hóa làm vách
% dịch lên trên 10 dB thì ca này đỏ TRƯỚC buổi demo chứ không phải trong.
T = dtmf_table();
allKeys = reshape(T.keys.', 1, []);
rng(2026);

for trial = 1:5
    s = allKeys(randi(12, 1, 12));
    y = dtmf_addnoise(dtmf_generate(s), 'snrDb', 10, 'type', 'awgn');
    testCase.verifyEqual(dtmf_decode_goertzel(y), s, ...
        sprintf('lan thu %d, chuoi %s', trial, s));
end
end
