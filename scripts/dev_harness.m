%% dev_harness.m
% DEV_HARNESS Kịch bản để coder tự kiểm tra toàn bộ pipeline BẰNG TAY, không
% cần chờ DTMFApp.mlapp (Epic E5) hay coeffs.mat của tổ S3 (Gói #5).
%
% Đây là file duy nhất trong repo ĐƯỢC PHÉP gọi figure/plot/sound - vì nó
% không thuộc src/ hay app/, chỉ là kịch bản thử nghiệm cá nhân.
%
% Cách dùng: chạy từng section (Ctrl+Enter) khi các hàm lần lượt được
% cài đặt xong.

clear; clc;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(genpath(fullfile(root, 'app')));

%% 1. Bảng tần số (không phụ thuộc hàm nào khác)
T = dtmf_table();
disp(T.keys);

%% 2. Sinh tín hiệu (cần dtmf_generate)
[x, t, meta] = dtmf_generate('0912345', 'fs', 8000);
figure; plot(t, x); title('DTMF goc'); xlabel('s');
sound(x, 8000);

%% 3. Cộng nhiễu (cần dtmf_addnoise)
y = dtmf_addnoise(x, 'snrDb', 15, 'type', 'awgn');
figure; plot(t, y); title('DTMF + nhieu AWGN 15dB'); xlabel('s');

%% 4. Giải mã bằng Goertzel (cần goertzel_power + dtmf_decode_goertzel)
[keysHat, info] = dtmf_decode_goertzel(y, 'fs', 8000);
fprintf('Goc : %s\n', meta.keys);
fprintf('Giai: %s\n', keysHat);

%% 5. Giải mã bằng FFT để so sánh
keysFft = dtmf_decode_fft(y, 'fs', 8000);
fprintf('FFT : %s\n', keysFft);

%% 6. Đo độ chính xác
m = dtmf_metrics(meta.keys, keysHat);
fprintf('Do chinh xac Goertzel: %.1f%%\n', 100 * m.acc);
