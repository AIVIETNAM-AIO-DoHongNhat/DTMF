%% run_bench.m
% RUN_BENCH Quét 3 phương pháp × SNR × loại nhiễu × ngưỡng năng lượng, ghi results/bench.mat
%
% Đây là nơi sinh ra MỌI con số đi vào chương 4 của báo cáo. Script KHÔNG vẽ
% một hình nào - vẽ là việc của scripts/make_figures.m. Tách đôi như vậy để
% sửa màu sắc một cái hình không phải chạy lại bốn phút quét.
%
% Các bước hoạt động:
%   1. Sinh nSeq chuỗi keysLen phím và tín hiệu sạch của chúng, rng(seed) cố định.
%   2. Với mỗi (loại nhiễu, SNR, chuỗi): cộng nhiễu MỘT LẦN rồi đưa CÙNG một y
%      cho cả ba bộ giải mã - có vậy so sánh mới công bằng.
%   3. Với mỗi bộ giải mã: đo thời gian, đếm khung, đếm lý do loại khung.
%   4. Với mỗi energyRatio trong {0.70, 0.40, 0}: quyết định LẠI từ info.E rồi
%      gộp phím, đo acc/editDist/confusion. Bước đo phổ (phần đắt) chỉ chạy một
%      lần cho cả ba ngưỡng - xử lý rủi ro R2 gần như miễn phí.
%   5. save('results/bench.mat', 'B').
%
% Vì sao script được gọi thẳng src/decode/* và src/util/*: luật CONTRACTS §2
% ràng buộc TẦNG ỨNG DỤNG (app/ui không tính toán, app/ đi qua dtmf_run).
% scripts/ và tests/ nằm ngoài đường đi của giao diện, và riêng script này bắt
% buộc phải đổi ngưỡng bên trong dtmf_decide - việc mà không chữ ký công khai
% nào của ba bộ giải mã cho phép.
%
% Cách dùng:  cd <repo>; addpath('scripts'); run_bench

clear;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));

%% 0. Tham số quét - đổi ở đây, không rải số vào thân vòng lặp
fs       = 8000;
nSeq     = 20;
keysLen  = 12;
seed     = 2026;
snrDb    = -5:2.5:30;
methods  = {'fft', 'goertzel', 'filterbank'};
noises   = {'awgn', 'hum50'};
enRatios = [0.70 0.40 0];
reasons  = {'none', 'level', 'twist', 'harmonic'};

nSnr = numel(snrDb);
nMet = numel(methods);
nNoi = numel(noises);
nEn  = numel(enRatios);

% str2func một lần ở ngoài. Gọi nó trong vòng trong cùng là 1800 lần phân giải
% tên hàm cho đúng ba hàm.
decoders = cellfun(@(m) str2func(['dtmf_decode_' m]), methods, 'UniformOutput', false);

%% 1. Sinh chuỗi phím và tín hiệu sạch - MỘT LẦN, dùng lại cho mọi điều kiện
% Ba phương pháp phải nhìn cùng một chuỗi ở cùng một mức nhiễu, nếu không thì
% chênh lệch đo được lẫn giữa "phương pháp khác nhau" và "đề bài khác nhau".
rng(seed);
T        = dtmf_table();
keysTrue = cell(1, nSeq);
xClean   = cell(1, nSeq);
for s = 1:nSeq
    % T.keys là 4×3; đánh chỉ số tuyến tính lấy đủ 12 phím.
    keysTrue{s} = T.keys(randi(numel(T.keys), 1, keysLen));
    xClean{s}   = dtmf_generate(keysTrue{s}, 'fs', fs);
end

%% 2. Cấp phát
acc        = zeros(nMet, nSnr, nNoi, nEn, nSeq);
editDist   = zeros(nMet, nSnr, nNoi, nEn, nSeq);
confusion  = zeros(12, 12, nMet, nSnr, nNoi);       % chỉ ở enRatios(1) = 0.70
rejectHist = zeros(numel(reasons), nMet, nSnr, nNoi);
tDecode    = zeros(nMet, 1);
nFrame     = zeros(nMet, 1);

%% 3. Vòng quét
% Ghim lại dòng số ngẫu nhiên: bước 1 đã tiêu một đoạn của nó, và ta muốn phần
% nhiễu bắt đầu từ một điểm biết trước để chạy lại cho đúng cùng một kết quả.
rng(seed);
tAll = tic;

for iNoi = 1:nNoi
    for iSnr = 1:nSnr
        for s = 1:nSeq
            % Cộng nhiễu MỘT LẦN cho cả ba phương pháp.
            y = dtmf_addnoise(xClean{s}, 'snrDb', snrDb(iSnr), ...
                              'type', noises{iNoi}, 'fs', fs);

            % Trừ trung bình y như app/dtmf_run.m làm - CONTRACTS §7.7. Bỏ bước
            % này thì nhánh hum50 lệch một chiều và cả ba bộ giải mã cùng sụp,
            % kết quả đo ra là của độ lệch một chiều chứ không phải của nhiễu ù.
            yd = y - mean(y);

            for iMet = 1:nMet
                tOne = tic;
                [keysHat, info] = decoders{iMet}(yd, 'fs', fs);
                tDecode(iMet) = tDecode(iMet) + toc(tOne);
                nFrame(iMet)  = nFrame(iMet) + numel(info.conf);

                for r = 1:numel(reasons)
                    rejectHist(r, iMet, iSnr, iNoi) = ...
                        rejectHist(r, iMet, iSnr, iNoi) + ...
                        nnz(strcmp(info.reject, reasons{r}));
                end

                for iEn = 1:nEn
                    kEn = redecide(info.E, enRatios(iEn));

                    % enRatios(1) là đúng ngưỡng mặc định của dtmf_decide, nên
                    % đường quyết định lại PHẢI trùng khít chuỗi mà bộ giải mã
                    % tự trả về. Chốt này là thứ duy nhất chứng minh ba cột
                    % energyRatio đang đo cùng một luật với phần còn lại của dự
                    % án; bỏ nó thì một thay đổi trong debounce sẽ làm cột 0.70
                    % lệch âm thầm khỏi mọi bảng khác.
                    if iEn == 1 && ~isequal(kEn, keysHat)
                        error('run_bench:redecideMismatch', ...
                            ['%s @ %g dB %s chuoi %d: quyet dinh lai cho "%s" ' ...
                             'con bo giai ma cho "%s".'], ...
                            methods{iMet}, snrDb(iSnr), noises{iNoi}, s, kEn, keysHat);
                    end

                    m = dtmf_metrics(keysTrue{s}, kEn);
                    acc(iMet, iSnr, iNoi, iEn, s)      = m.acc;
                    editDist(iMet, iSnr, iNoi, iEn, s) = m.editDist;
                    if iEn == 1
                        confusion(:, :, iMet, iSnr, iNoi) = ...
                            confusion(:, :, iMet, iSnr, iNoi) + m.confusion;
                    end
                end
            end
        end
        fprintf('  %-6s SNR %+5.1f dB | acc fft %.3f  goe %.3f  fb %.3f\n', ...
            noises{iNoi}, snrDb(iSnr), ...
            mean(acc(1, iSnr, iNoi, 1, :)), ...
            mean(acc(2, iSnr, iNoi, 1, :)), ...
            mean(acc(3, iSnr, iNoi, 1, :)));
    end
end

runSec = toc(tAll);

%% 4. Chi phí lý thuyết - đếm phép NHÂN THỰC cho mỗi khung
% Ba con số này là trục hoành của hình H4.4. Đếm bằng công thức chứ không tra
% bảng: đổi frameN hay r thì chúng tự đi theo.
frameN = struct('fft', 256, 'goertzel', 205, 'filterbank', 205);
hop    = struct('fft', 128, 'goertzel', 205, 'filterbank', 205);

% FFT: nhân cửa sổ (N) + radix-2 ((N/2)·log2 N phép nhân PHỨC = 4 phép nhân
% thực mỗi phép) + |X|² tại 8 bin (2 phép mỗi bin).
mulFft = frameN.fft + 4 * (frameN.fft/2) * log2(frameN.fft) + 2*8;

% Goertzel: mỗi bin chạy N vòng, mỗi vòng ĐÚNG MỘT phép nhân thực (c*s1), cộng
% 4 phép ở đuôi khi quy ra công suất P = s1^2 + s2^2 - c*s1*s2, đếm lần lượt
% s1^2, s2^2, c*s1 và (c*s1)*s2 - hệ số c đã tính sẵn ngoài vòng lặp. 8 bin.
mulGoe = 8 * (frameN.goertzel + 4);

% Ngân hàng bộ lọc: biquad trực tiếp dạng II cần numel(b)+numel(a)-1 = 5 phép
% nhân mỗi mẫu, chạy trên 14 bộ; cộng 1 phép bình phương mỗi mẫu mỗi bộ khi lấy
% năng lượng. Tín hiệu được lọc một lần rồi mới chia khung, nên chi phí quy về
% MỘT khung là hop mẫu chứ không phải frameN mẫu (ở đây hai số bằng nhau).
% Thực tế b(2) = 0 nên còn 4 phép, nhưng đếm theo cấu trúc mới là con số so
% sánh được với hai nhánh kia.
bank    = design_bpf_bank('fs', fs, 'coeffs', '');
mulPerS = numel(bank) * (numel(bank(1).b) + numel(bank(1).a) - 1 + 1);
mulFb   = mulPerS * hop.filterbank;

mulPerFrame  = [mulFft; mulGoe; mulFb];
framesPerSec = fs ./ [hop.fft; hop.goertzel; hop.filterbank];

%% 5. Đóng gói và ghi đĩa
B = struct();
B.meta = struct('created',  datetime('now'), ...
                'fs',       fs, ...
                'nSeq',     nSeq, ...
                'keysLen',  keysLen, ...
                'seed',     seed, ...
                'minRun',   2, ...
                'runSec',   runSec, ...
                'matlab',   version);

B.snrDb        = snrDb;
B.methods      = methods;
B.noises       = noises;
B.energyRatios = enRatios;
B.reasons      = reasons;
B.keysTrue     = keysTrue;

% Thứ tự chiều ghi thành chữ, ngay trong file. Sáu tháng nữa không ai nhớ được
% chiều thứ ba của một mảng 5 chiều là gì, và đoán sai thì hình vẫn vẽ ra.
B.dims = struct( ...
    'acc',        'method × snr × noise × energyRatio × seq', ...
    'editDist',   'method × snr × noise × energyRatio × seq', ...
    'confusion',  'keyTrue(12) × keyHat(12) × method × snr × noise, chỉ energyRatio = 0.70', ...
    'rejectHist', 'reason(4) × method × snr × noise, chỉ energyRatio = 0.70', ...
    'perMethod',  'method');

B.acc        = acc;
B.accMean    = mean(acc, 5);
B.editDist   = editDist;
B.confusion  = confusion;
B.rejectHist = rejectHist;

% ⚠️ timePerFrameUs KHÔNG tái lập được, khác hẳn mọi trường còn lại của B.
% Đo được 23/09/2026: bốn lần chạy trên CÙNG một máy cho 28.9 / 82.7 / 88.8 /
% 82.9 us mỗi khung cho nhánh FFT - chênh gần 3 lần, tùy máy đang bận gì. Thứ
% ổn định là TỈ SỐ giữa ba nhánh (Goertzel tốn ~2.6 lần thời gian mỗi phép nhân
% so với FFT ở cả bốn lần đo). Đừng trích con số tuyệt đối vào báo cáo như một
% hằng số của thuật toán; nó là số của một lần chạy trên một máy.
B.timePerFrameUs = 1e6 * tDecode ./ nFrame;
B.nFrame         = nFrame;
B.mulPerFrame    = mulPerFrame;
B.framesPerSec   = framesPerSec;

% Hai đại lượng quy về MỘT GIÂY ÂM THANH. Chỉ chúng mới so sánh được: FFT xử lý
% 62.5 khung/giây còn hai nhánh kia 39.0 khung/giây, nên "mỗi khung" là ba thước
% đo khác nhau đội lốt một cái tên.
B.mulPerAudioSec = mulPerFrame .* framesPerSec;
B.msPerAudioSec  = 1e-3 * B.timePerFrameUs .* framesPerSec;

outDir = fullfile(root, 'results');
if ~isfolder(outDir)
    mkdir(outDir);
end
out = fullfile(outDir, 'bench.mat');
save(out, 'B');

fprintf('\nDa ghi %s (%.1f KB) sau %.1f giay\n', out, dir(out).bytes/1024, runSec);
fprintf('  %d dieu kien = %d phuong phap x %d SNR x %d nhieu x %d nguong x %d chuoi\n', ...
    nMet*nSnr*nNoi*nEn*nSeq, nMet, nSnr, nNoi, nEn, nSeq);
for iMet = 1:nMet
    fprintf('  %-11s %8.1f us/khung | %6.2f ms/giay am thanh | %8.0f phep nhan/giay\n', ...
        methods{iMet}, B.timePerFrameUs(iMet), B.msPerAudioSec(iMet), B.mulPerAudioSec(iMet));
end


function keys = redecide(E, energyRatio)
%REDECIDE Chạy lại luật quyết định trên E đã đo sẵn, với một ngưỡng khác
%   Bước đo phổ là phần đắt nhất và KHÔNG phụ thuộc energyRatio, nên quét ba
%   ngưỡng chỉ tốn thêm vài phần trăm thời gian thay vì gấp ba.

n      = size(E, 2);
rowIdx = zeros(1, n);
colIdx = zeros(1, n);
for i = 1:n
    [rowIdx(i), colIdx(i)] = dtmf_decide(E(:, i), 'energyRatio', energyRatio);
end

% minRun mặc định - phải là ĐÚNG luật mà ba bộ giải mã dùng, xem CONTRACTS §6(f).
keys = dtmf_debounce(rowIdx, colIdx);
end
