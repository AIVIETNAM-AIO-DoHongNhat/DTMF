%% LÝ THUYẾT XỬ LÝ TÍN HIỆU SỐ CHO DỰ ÁN DTMF
% *Chủ đề 4: Hệ thống tự động phát và giải mã tín hiệu điện thoại DTMF*
%% Mục lục
%
% # Tín hiệu và sóng sin
% # Lấy mẫu, Nyquist, chồng phổ
% # Chuẩn DTMF
% # Năng lượng, công suất, decibel, SNR
% # Miền tần số: DFT và FFT
% # Chia khung
% # Bộ lọc số
% # Thuật toán Goertzel
% # Ngân hàng bộ lọc
% # Luật quyết định
% # Từ khung đến chuỗi phím
% # Đánh giá kết quả
% # Bảng thông số chốt
%
%% Ba thông số nền của dự án
%
%    fs = 8000 Hz (tần số lấy mẫu)
%    tone/nghỉ = 100 ms / 50 ms
%    khung = 205 mẫu (Goertzel, ngân hàng lọc) hoặc 256 mẫu (FFT)
%
% *Lưu ý quan trọng:* Do dự án chỉ dùng 12 phím, không dùng cột thứ 4 (1633 Hz), thường dùng cho 4 phím A,B,C,D.
% Bin thứ 8 trong vector năng lượng là *bin hài bậc 2*, dùng để chống nhận
% nhầm tiếng nói, không phải 1633 Hz.

clear; close all; clc;
fs   = 8000;
FROW = [697 770 852 941];
FCOL = [1209 1336 1477];
FALL = [FROW FCOL];
KEYS = ['123'; '456'; '789'; '*0#'];
fprintf('MATLAB %s sẵn sàng.\n', version('-release'));


%% 1. Tín hiệu và sóng sin
% *Tín hiệu* là một đại lượng biến thiên mang thông tin. Ở đây là áp suất âm
% thanh biến thiên theo thời gian.
%
% *Sóng sin* là viên gạch cơ bản, vì mọi tín hiệu tuần hoàn đều phân tích
% được thành tổng các sóng sin (Fourier):
%
% $$x(t) = A\sin(2\pi f t + \varphi)$$
%
% * $A$ - biên độ, quyết định độ to
% * $f$ - tần số (Hz), số chu kỳ mỗi giây, quyết định độ cao thấp
% * $\varphi$ - pha ban đầu (rad)
% * chu kỳ $T = 1/f$
%
% Dạng rời rạc, thay $t$ bằng $n/f_s$:
%
% $$x[n] = A\sin\left(2\pi f \frac{n}{f_s} + \varphi\right)$$
%
% *Cộng hai sóng sin khác tần số* cho ra một dạng sóng *không còn là sin*,
% nhưng phổ của nó có 2 đỉnh nổi bật rõ rệt, các tần sô còn lại tuy khác 0 nhưng thấp hơn nhiều. Đây là nền tảng của DTMF: trộn
% trong miền thời gian, tách trong miền tần số.

n = 0:399;
x1 = sin(2*pi*770*n/fs);
x2 = sin(2*pi*1336*n/fs);

figure('Position',[80 80 900 460]);
subplot(3,1,1); plot(n/fs*1000, x1, 'LineWidth',1); grid on;
title('770 Hz'); ylabel('biên độ');
subplot(3,1,2); plot(n/fs*1000, x2, 'LineWidth',1); grid on;
title('1336 Hz'); ylabel('biên độ');
subplot(3,1,3); plot(n/fs*1000, x1+x2, 'LineWidth',1); grid on;
title('Tổng (không còn là sóng sin)'); xlabel('ms'); ylabel('biên độ');

fprintf('Chu kỳ 770 Hz  = %.3f ms = %.2f mẫu\n', 1000/770, fs/770);
fprintf('Chu kỳ 1336 Hz = %.3f ms = %.2f mẫu\n', 1000/1336, fs/1336);
fprintf('Biên độ đỉnh của tổng = %.4f  (không phải 2, vì hai sóng lệch pha nhau)\n', max(x1+x2));


%% 2. Lấy mẫu, Nyquist, chồng phổ
% *Lấy mẫu* là đo giá trị tín hiệu liên tục tại các thời điểm cách đều nhau
% $T_s = 1/f_s$. Mẫu thứ $n$ ứng với thời điểm $t = n/f_s$.
%
% *Định lý lấy mẫu Nyquist–Shannon:* Nếu tín hiệu dao động nhanh nhất ở 
% tần số $$f_{max}$$ thì phải lấy mẫu
% **nhanh hơn gấp đôi** con số đó. Đồng nghĩa với
% khôi phục được nguyên vẹn tín hiệu khi
%
% $$f_s > 2 f_{max}$$
%
% Nửa tần số lấy mẫu $f_s/2$ gọi là *tần số Nyquist*. Với $f_s = 8000$ Hz thì
% Nyquist $= 4000$ Hz. Tần số cao nhất của dự án là 1477 Hz, còn dư rất nhiều.
%
% *Chồng phổ (aliasing):* nếu $f > f_s/2$, tần số đó bị "gập" về thành
%
% $$f_{alias} = \left| f - f_s \cdot \mathrm{round}(f/f_s) \right|$$
%
% và *không có cách nào cứu được* - thông tin mất ngay lúc lấy mẫu. Đó là lý
% do trong phần cứng luôn có bộ lọc chống chồng phổ đặt *trước* bộ ADC.
%
% *Chỉ số từ 0 hay từ 1.* Công thức lý thuyết đánh số mẫu từ $n = 0$. MATLAB
% đánh chỉ số mảng từ 1. Quy đổi: $x[n] \leftrightarrow$ |x(n+1)|. Đây là
% nguồn lỗi phổ biến nhất khi chuyển công thức thành code - bin $k$ của DFT
% nằm ở |X(k+1)|.

fprintf('Nyquist = %d Hz\n', fs/2);
fprintf('%-10s %-12s %s\n', 'f thật', 'f sau lấy mẫu', 'Ghi chú');
for f = [700 1477 3900 4100 5000 7500 8200]
    fa = abs(f - fs*round(f/fs));
    if f <= fs/2, gc = 'giữ nguyên'; else, gc = 'BỊ GẬP (aliasing)'; end
    fprintf('%-10d %-12.0f %s\n', f, fa, gc);
end

fThat = 1477;
tt = linspace(0, 0.004, 2000);
figure('Position',[80 80 900 300]); hold on;
plot(tt*1000, sin(2*pi*fThat*tt), '-', 'LineWidth',1, 'Color',[.55 .55 .55]);
for fsThu = [8000 2000]
    ts = (0:round(0.004*fsThu)-1)/fsThu;
    plot(ts*1000, sin(2*pi*fThat*ts), 'o--', 'MarkerSize',5, 'LineWidth',1);
end
legend('sóng thật 1477 Hz','lấy mẫu 8000 Hz','lấy mẫu 2000 Hz', ...
       'Location','southeast','FontSize',8);
xlabel('ms'); grid on; hold off; title('Lấy mẫu đủ và lấy mẫu thiếu');


%% 3. Chuẩn DTMF
% *DTMF* = _Dual-Tone Multi-Frequency_. Mỗi phím phát *đồng thời hai tần số*:
% một ở nhóm hàng (thấp), một ở nhóm cột (cao).
%
%                  1209 Hz   1336 Hz   1477 Hz
%       697 Hz  |     1    |    2    |    3    |
%       770 Hz  |     4    |    5    |    6    |
%       852 Hz  |     7    |    8    |    9    |
%       941 Hz  |     *    |    0    |    #    |
%
% *Vì sao chọn đúng 7 tần số này*
%
% # Không tần số nào là bội số nguyên của tần số khác, nên hài của tần số này
%   không rơi trùng một tần số chuẩn khác.
% # Hai nhóm tách xa nhau (nhóm hàng $\le 941$ Hz, nhóm cột $\ge 1209$ Hz),
%   lọc riêng từng nhóm dễ.
% # Toàn bộ nằm trong băng thoại 300–3400 Hz nên đi qua được đường dây.
%
% Khoảng cách gần nhau nhất là *73 Hz* (697 và 770). Con số này quyết định độ
% phân giải tối thiểu, xem mục 5.
%
% *Thông số chốt của dự án*
%
%    tone/nghỉ tối thiểu (ITU-T Q.24) = 40 ms
%    tone/nghỉ dự án dùng = 100 ms / 50 ms
%    dung sai tần số nhận nếu lệch <= 1.5%, từ chối nếu lệch >= 3.5%
%    twist thuận <= 4 dB, nghịch <= 8 dB
%
% *Twist* là độ chênh mức giữa tone cột và tone hàng:
%
% $$\mathrm{twist_{dB}} = 10\log_{10}\frac{P_{cột}}{P_{hàng}}$$
%
% Dương là twist thuận (cột mạnh hơn), âm là twist nghịch. Twist xuất hiện
% thật vì đường dây suy hao các tần số không đều nhau. Twist quá lớn là dấu
% hiệu khung đó không phải một phím hợp lệ.
%
% *Hài bậc 2 và talk-off.* Sóng sin thuần không có hài. Tiếng nói người thì
% có rất nhiều hài. *Talk-off* là hiện tượng bộ giải mã nhận nhầm tiếng nói
% thành phím bấm. Cách chống: đo thêm năng lượng tại tần số $2f$ của đỉnh
% mạnh nhất; nếu lớn thì nghi là tiếng nói và từ chối khung. *Đây là lý do có
% bin thứ 8* trong vector năng lượng.

fprintf('Bảng phím và cặp tần số:\n');
for i = 1:4
    for j = 1:3
        fprintf('  %c = %4d + %4d Hz', KEYS(i,j), FROW(i), FCOL(j));
    end
    fprintf('\n');
end

fprintf('\nKiểm tra: tần số nào là bội nguyên của tần số khác?\n');
viPham = 0;
for i = 1:7
    for j = 1:7
        if i ~= j
            ty = FALL(i)/FALL(j);
            if abs(ty - round(ty)) < 0.02 && round(ty) >= 2
                fprintf('  VI PHẠM: %d = %.2f x %d\n', FALL(i), ty, FALL(j));
                viPham = viPham + 1;
            end
        end
    end
end
fprintf('  Số cặp vi phạm: %d  -> thiết kế đạt yêu cầu\n', viPham);

kc = diff(sort(FALL));
fprintf('\nKhoảng cách giữa các tần số liền kề: %s\n', mat2str(kc));
fprintf('Nhỏ nhất = %d Hz (697 và 770)\n', min(kc));


%% 4. Năng lượng, công suất, decibel, SNR
% Với tín hiệu số $x[n]$ gồm $N$ mẫu:
%
% $$E_x = \sum_{n=0}^{N-1} x[n]^2, \qquad P_x = \frac{1}{N}\sum_{n=0}^{N-1} x[n]^2 = \frac{E_x}{N}$$
%
% Sóng sin biên độ $A$ có công suất trung bình $A^2/2$.
%
% *Decibel* so sánh hai đại lượng bằng logarit:
%
% $$\mathrm{dB} = 10\log_{10}\frac{P_1}{P_2} \quad\text{(công suất)}, \qquad
%   \mathrm{dB} = 20\log_{10}\frac{A_1}{A_2} \quad\text{(biên độ)}$$
%
% Hai công thức nhất quán vì $P \propto A^2$ nên $10\log_{10}(A^2) = 20\log_{10}(A)$.
%
%    tỉ số công suất    dB      tỉ số biên độ
%       x2             +3          x1.41
%       x4             +6          x2
%       x10            +10         x3.16
%       x100           +20         x10
%       x0.5           -3          x0.71
%
% *Trong dự án, |E| là công suất* ($|X[k]|^2$), nên *luôn dùng* |10*log10|.
% Dùng nhầm |20*log10| làm mọi ngưỡng lệch gấp đôi.
%
% *SNR* (_Signal-to-Noise Ratio_):
%
% $$\mathrm{SNR_{dB}} = 10\log_{10}\frac{P_x}{P_v}$$
%
% *AWGN* = nhiễu *cộng*, *trắng* (đều ở mọi tần số), phân bố *Gauss* - hàm
% |randn| của MATLAB. Muốn nhiễu có đúng SNR mục tiêu thì sinh nhiễu thô rồi
% co giãn theo hệ số dưới đây.

A = 1;
n = 0:fs-1;
xs = A*sin(2*pi*770*n/fs);
fprintf('Sin biên độ %.1f: Px đo được = %.6f, lý thuyết A^2/2 = %.6f\n', ...
        A, mean(xs.^2), A^2/2);

fprintf('\n%-18s %-9s %s\n', 'tỉ số công suất', 'dB', 'tỉ số biên độ');
for ty = [2 4 10 100 0.5]
    fprintf('%-18g %-9.2f %.3f\n', ty, 10*log10(ty), sqrt(ty));
end

fprintf('\nKiểm chứng bộ sinh nhiễu theo SNR đặt trước:\n');
rng(0);
x = sin(2*pi*770*n/fs) + sin(2*pi*1336*n/fs);
for snrDb = [30 20 10 0 -10]
    v0 = randn(size(x));
    v  = v0 * sqrt( mean(x.^2) / (mean(v0.^2) * 10^(snrDb/10)) );
    y  = x + v;
    doLai = 10*log10( sum(x.^2) / sum((y-x).^2) );
    fprintf('  đặt %+4d dB  ->  đo lại %+7.3f dB   (sai %.3f dB)\n', ...
            snrDb, doLai, abs(doLai-snrDb));
end


%% 5. Miền tần số: DFT và FFT
% Câu hỏi cần trả lời: _trong đoạn tín hiệu này có bao nhiêu thành phần ở tần
% số f?_ Phép *biến đổi Fourier rời rạc (DFT)* trả lời:
%
% $$X[k] = \sum_{n=0}^{N-1} x[n]\, e^{-j2\pi kn/N}, \qquad k = 0,1,\dots,N-1$$
%
% Nhân tín hiệu với một sóng chuẩn ở tần số thứ $k$ rồi cộng lại. Có tần số
% đó thì tổng lớn; không có thì các số dương âm triệt tiêu, tổng gần 0.
%
% *Bin và độ phân giải*
%
% $$f_k = k\frac{f_s}{N}, \qquad \Delta f = \frac{f_s}{N}, \qquad k = \mathrm{round}\!\left(\frac{N f}{f_s}\right)$$
%
% Với tín hiệu thực, phổ đối xứng: bin $k$ và bin $N-k$ chứa cùng thông tin,
% chỉ cần xét $k = 0 \dots N/2$.
%
% *FFT* tính cùng kết quả DFT nhưng nhanh hơn: $O(N^2) \rightarrow O(N\log_2 N)$.
% Nhược điểm cho bài toán này: nó tính *tất cả* $N$ bin trong khi ta chỉ cần
% 8 bin. Đó là động lực của Goertzel ở mục 8.

%%
% *5.1 Ví dụ số kiểm chứng: N = 16, k = 3*
%
% Cho $x[n] = \cos(2\pi \cdot 3n/16)$ - một cos nằm *đúng* trên bin 3. Viết
% $\cos\theta = (e^{j\theta} + e^{-j\theta})/2$ rồi thay vào DFT tại $k=3$:
%
% $$X[3] = \sum_{n} \tfrac{1}{2} \cdot 1 \;+\; \sum_{n} \tfrac{1}{2} e^{-j2\pi \cdot 6n/16} = \frac{N}{2} + 0 = 8$$
%
% Tổng thứ hai bằng 0 vì đó là tổng các điểm cách đều trên đường tròn đơn vị.
% Vậy $|X[3]|^2 = 64$. *Đây là ví dụ kiểm chứng bắt buộc trong CONTRACTS.md.*

N = 16; k = 3;
n = 0:N-1;
x16 = cos(2*pi*k*n/N);
X16 = fft(x16);
fprintf('|X[3]|^2  = %.6f   (MATLAB: X(k+1) = X(4))\n', abs(X16(k+1))^2);
fprintf('|X[13]|^2 = %.6f   (bin đối xứng N-k = 13, ở X(14))\n', abs(X16(N-k+1))^2);
fprintf('Lý thuyết = %.6f\n', (N/2)^2);
fprintf('Các bin còn lại đều ~0: tổng = %.3e\n', ...
        sum(abs(X16([1:3 5:13 15:16])).^2));

%%
% *5.2 Định lý Parseval*
%
% Năng lượng đo ở miền thời gian bằng năng lượng đo ở miền tần số:
%
% $$\sum_{n=0}^{N-1} x[n]^2 = \frac{1}{N}\sum_{k=0}^{N-1} |X[k]|^2$$
%
% Hệ quả dùng trong luật quyết định: một cos thuần nằm đúng bin $k$ chiếm tỉ
% lệ năng lượng $2|X[k]|^2/(N \sum x^2)$ - hệ số 2 vì năng lượng chia đều cho
% bin $k$ và bin $N-k$.

fprintf('Miền thời gian : %.6f\n', sum(x16.^2));
fprintf('Miền tần số    : %.6f\n', sum(abs(X16).^2)/N);
fprintf('Tỉ lệ năng lượng của bin 3 (cả cặp k và N-k): %.2f %%\n', ...
        2*abs(X16(k+1))^2/(N*sum(x16.^2))*100);

%%
% *5.3 Đánh đổi thời gian – tần số*
%
% Muốn tách 697 và 770 Hz (cách 73 Hz) thì cần $\Delta f$ đủ nhỏ, tức $N$ đủ
% lớn. Nhưng tone chỉ dài 100 ms = 800 mẫu; $N$ lớn thì khung dài, dễ vắt
% ngang hai phím liên tiếp và phản ứng chậm. Đây là đánh đổi cơ bản nhất của
% xử lý tín hiệu: *độ phân giải tần số đổi lấy độ phân giải thời gian.*

fprintf('%6s | %9s | %11s | %s\n','N','df (Hz)','thời lượng','Đánh giá');
fprintf('%s\n', repmat('-',1,66));
for Nt = [64 128 205 256 512 800 1024]
    df = fs/Nt;  ms = Nt/fs*1000;
    if df >= 73
        gc = 'KHÔNG tách nổi 697/770';
    elseif ms > 100
        gc = 'dài hơn tone 100 ms';
    else
        gc = 'dùng được';
    end
    fprintf('%6d | %9.2f | %8.1f ms | %s\n', Nt, df, ms, gc);
end
fprintf('\nDự án chọn N = 205 (Goertzel, ngân hàng lọc) và N = 256 (FFT).\n');

%%
% *5.4 Bảng bin chuẩn - và lý do thật sự chọn N = 205*
%
% Tần số DTMF hầu như không rơi đúng tâm bin. Độ lệch giữa tâm bin $f_k$ và
% tần số thật quy ra phần trăm phải *nhỏ hơn dung sai nhận 1.5%* của ITU-T,
% nếu không thì chính bộ giải mã tự đẩy tần số ra ngoài vùng chấp nhận.

for N = [205 256]
    fprintf('\n--- N = %d,  df = %.2f Hz ---\n', N, fs/N);
    fprintf('%8s %10s %5s %11s %9s\n','f (Hz)','N*f/fs','k','f_k (Hz)','lệch %%');
    lechMax = 0;
    for f = FALL
        tho = N*f/fs;  k = round(tho);  fk = k*fs/N;  pc = (fk-f)/f*100;
        lechMax = max(lechMax, abs(pc));
        fprintf('%8d %10.2f %5d %11.2f %+9.2f\n', f, tho, k, fk, pc);
    end
    fprintf('Lệch lớn nhất %.2f%% ', lechMax);
    if lechMax < 1.5, fprintf('< 1.5%% -> ĐẠT\n'); else, fprintf('-> KHÔNG ĐẠT\n'); end
end

%%
% *5.5 Rò rỉ phổ và hàm cửa sổ*
%
% DFT ngầm coi khung $N$ mẫu lặp lại tuần hoàn. Nếu khung không chứa số chu
% kỳ nguyên thì chỗ nối bị gãy, sinh ra các thành phần tần số giả - gọi là
% *rò rỉ phổ*. Vì 770 Hz ứng với $N f/f_s = 19.73$ chứ không phải số nguyên,
% rò rỉ luôn xảy ra.
%
% Cách giảm: nhân khung với một *cửa sổ* vuốt hai đầu về 0. Cửa sổ Hamming:
%
% $$w[n] = 0.54 - 0.46\cos\!\left(\frac{2\pi n}{N-1}\right), \qquad n = 0 \dots N-1$$
%
% Phổ của một cửa sổ có *búp chính* (độ rộng quyết định khả năng tách hai tần
% số gần nhau) và *búp phụ* (mức rò ra xa). Đánh đổi: búp phụ thấp thì búp
% chính rộng.
%
%    Cửa sổ        Độ rộng búp chính    Búp phụ cao nhất
%    Chữ nhật           4*pi/N              -13 dB
%    Hann               8*pi/N              -31 dB
%    Hamming            8*pi/N              -41 dB
%    Blackman          12*pi/N              -57 dB
%
% *Trong dự án:* bộ giải mã FFT dùng Hamming, N = 256, hop = 128. Goertzel
% *không* nhân cửa sổ.

N = 256;
nn = 0:N-1;
x = sin(2*pi*770*nn/fs) + sin(2*pi*1336*nn/fs);

figure('Position',[80 80 900 300]); hold on;
for k = 1:2
    if k == 1, w = ones(1,N);        nhan = 'Chữ nhật (không cửa sổ)';
    else,      w = hammingTay(N)';   nhan = 'Hamming';
    end
    S = 20*log10(abs(fft(x.*w)) + 1e-12);  S = S - max(S);
    fr = (0:N-1)*fs/N;
    plot(fr(1:N/2), S(1:N/2), 'LineWidth',1, 'DisplayName', nhan);
end
xlim([400 2200]); ylim([-90 5]); legend('Location','northeast','FontSize',9);
xlabel('Hz'); ylabel('dB'); grid on; hold off;
title('Rò rỉ phổ: chữ nhật và Hamming');

S1 = abs(fft(x));            S1 = S1/max(S1);
S2 = abs(fft(x.*hammingTay(N)')); S2 = S2/max(S2);
xa = round(1000*N/fs)+1;     % một bin ở xa hai đỉnh (~1000 Hz)
fprintf('Mức rò tại bin ~%.0f Hz:\n', (xa-1)*fs/N);
fprintf('  chữ nhật %7.2f dB\n', 20*log10(S1(xa)));
fprintf('  Hamming  %7.2f dB   -> thấp hơn %.1f dB\n', ...
        20*log10(S2(xa)), 20*log10(S1(xa))-20*log10(S2(xa)));


%% 6. Chia khung
% Một chuỗi phím dài hàng giây và *tần số thay đổi theo thời gian*. DFT trên
% cả tín hiệu chỉ cho biết "có những tần số nào", không cho biết "lúc nào".
% Vì vậy phải cắt tín hiệu thành các *khung* ngắn rồi phân tích từng khung.
%
% * |frameN| - số mẫu mỗi khung
% * |hop| - bước nhảy giữa đầu hai khung liên tiếp
%
% |hop = frameN| là khung nối tiếp không chồng (Goertzel: 205/205).
% |hop < frameN| là khung chồng lấp (FFT: 256/128, chồng 50%).
%
% Số khung và chỉ số mẫu của khung thứ $i$ (MATLAB, $i$ từ 1):
%
% $$n_{frame} = \left\lfloor \frac{L - frameN}{hop} \right\rfloor + 1, \qquad
%   i_1 = (i-1)\,hop + 1, \qquad i_2 = i_1 + frameN - 1$$
%
% Khung cuối không đủ |frameN| mẫu thì *bỏ*, không đệm số 0. Nếu
% $L < frameN$ thì $n_{frame} = 0$.

fprintf('Chuỗi 7 phím, mỗi phím 100 ms tone + 50 ms nghỉ:\n');
L = round(7 * 0.150 * fs);
fprintf('  L = %d mẫu = %.2f s\n', L, L/fs);
for cfg = [205 205; 256 128]'
    frameN = cfg(1); hop = cfg(2);
    nFrame = floor((L - frameN)/hop) + 1;
    fprintf('  frameN=%3d hop=%3d -> %3d khung; 1 tone (800 mẫu) trải %.1f khung\n', ...
            frameN, hop, nFrame, 800/hop);
end
fprintf('\nMỗi phím trải trên nhiều khung -> phải gộp lại, xem mục 11.\n');


%% 7. Bộ lọc số
% *Bộ lọc* nhận $x[n]$, trả $y[n]$, giữ lại một số tần số và làm yếu các tần
% số khác. Bộ lọc *thông dải* chỉ cho một dải hẹp quanh $f_0$ đi qua.
%
% *Phương trình sai phân* bậc 2:
%
% $$y[n] = b_0 x[n] + b_1 x[n-1] + b_2 x[n-2] - a_1 y[n-1] - a_2 y[n-2]$$
%
% Trong MATLAB: |y = filter(b, a, x)| với |b = [b0 b1 b2]|, |a = [1 a1 a2]|.
%
%    So sánh FIR và IIR
%
%                        FIR                     IIR
%    hồi tiếp            không (chỉ có b)        có (có a)
%    ổn định             luôn ổn định            có thể mất ổn định
%    hệ số cho dải hẹp   rất nhiều               rất ít (bậc 2 là đủ)
%    pha                 có thể tuyến tính       phi tuyến
%
% Dự án cần dải *rất hẹp* với chi phí thấp, nên chọn *IIR*.
%
% *Hàm truyền.* Coi $z^{-1}$ là phép trễ một mẫu:
%
% $$H(z) = \frac{b_0 + b_1 z^{-1} + b_2 z^{-2}}{1 + a_1 z^{-1} + a_2 z^{-2}}$$
%
% * *Điểm không* - giá trị $z$ làm tử số bằng 0, tần số đó bị triệt
% * *Điểm cực* - giá trị $z$ làm mẫu số bằng 0, tần số đó được khuếch đại
% * Đáp ứng tần số: thay $z = e^{j\omega}$, với $f = \omega f_s/(2\pi)$
% * *Ổn định BIBO*: mọi điểm cực phải nằm *trong* đường tròn đơn vị, $|p| < 1$
%
% Cực càng gần đường tròn đơn vị tại góc $\omega_0$ thì cộng hưởng càng mạnh
% và càng hẹp quanh $f_0$.

%%
% *7.1 Bộ cộng hưởng bậc 2 - dạng dùng trong dự án*
%
% $$H(z) = G\,\frac{1 - z^{-2}}{1 - 2r\cos(\omega_0)z^{-1} + r^2 z^{-2}},
%   \qquad \omega_0 = \frac{2\pi f_0}{f_s}$$
%
% * hai điểm không tại $z = \pm 1$, triệt thành phần một chiều và Nyquist
% * hai điểm cực tại $z = re^{\pm j\omega_0}$, cộng hưởng tại $f_0$
% * $G$ chọn sao cho $|H(f_0)| = 1$
%
% *Băng thông và hệ số phẩm chất*
%
% $$BW \approx \frac{(1-r)f_s}{\pi}, \qquad Q = \frac{f_0}{BW}$$
%
% Với $r = 0.99$, $f_s = 8000$: $BW \approx 25.5$ Hz, khớp yêu cầu
% "$\approx 25$ Hz" trong CONTRACTS.md.

f0 = 697;  r = 0.99;
[b, a] = boLoc(f0, r, fs);
fprintf('Bộ lọc %d Hz, r = %.2f\n', f0, r);
fprintf('  b = [%10.7f %10.7f %10.7f]\n', b);
fprintf('  a = [%10.7f %10.7f %10.7f]\n', a);
fprintf('  |H(f0)| = %.6f  (phải bằng 1 sau chuẩn hoá)\n', abs(dapUngTanSo(b,a,f0,fs)));
cuc = roots(a);
fprintf('  |cực|   = %.4f và %.4f  -> đều < 1 nên ổn định BIBO\n', abs(cuc));
fprintf('  góc cực -> tần số cộng hưởng %.2f Hz (đặt %d Hz)\n', ...
        abs(angle(cuc(1)))*fs/(2*pi), f0);

fprintf('\n%8s %10s %10s\n','f0 (Hz)','BW (Hz)','Q');
BW = (1-r)*fs/pi;
for f = FALL
    fprintf('%8d %10.1f %10.1f\n', f, BW, f/BW);
end
fprintf('Nhận xét: BW gần như không đổi, f0 tăng nên Q tăng theo tần số.\n');

fTruc = 0:1:fs/2;
figure('Position',[80 80 900 320]); hold on;
for f = FALL
    [bb, aa] = boLoc(f, r, fs);
    plot(fTruc, 20*log10(abs(dapUngTanSo(bb,aa,fTruc,fs)) + 1e-12), 'LineWidth',1);
end
xlim([600 1600]); ylim([-60 5]); xlabel('Hz'); ylabel('dB'); grid on; hold off;
title('Bảy bộ lọc cộng hưởng, r = 0.99');

%%
% *7.2 Ràng buộc thật sự quyết định giá trị r*
%
% $r$ càng gần 1 thì dải càng hẹp - nhưng bộ lọc *phản ứng càng chậm*. Thời
% hằng và thời gian ổn định:
%
% $$\tau = \frac{-1}{f_s \ln r}, \qquad t_{on\text{-}dinh} \approx 5\tau$$
%
% Thời gian ổn định *phải nhỏ hơn độ dài tone 100 ms*, nếu không bộ lọc chưa
% kịp lên hết biên độ thì tone đã tắt. Đây là ràng buộc cứng, và nó cho thấy
% $r = 0.99$ không phải chọn tuỳ tiện mà là *giới hạn trên*.

fprintf('%8s %10s %10s %12s   %s\n','r','BW (Hz)','Q(697)','5*tau (ms)','Kết luận');
fprintf('%s\n', repmat('-',1,68));
for rr = [0.90 0.95 0.98 0.99 0.995 0.999]
    bw  = (1-rr)*fs/pi;
    tau = -1/(fs*log(rr));
    if 5*tau < 0.100, kl = 'kịp ổn định trong tone 100 ms';
    else,             kl = 'CHẬM hơn tone -> không dùng được'; end
    fprintf('%8.4g %10.1f %10.1f %12.1f   %s\n', rr, bw, 697/bw, 5*tau*1000, kl);
end

%%
% *7.3 Hai vấn đề của thiết kế thực tế*
%
% *Biến đổi song tuyến* (_bilinear transform_) là cách thiết kế bộ lọc số từ
% một bộ lọc tương tự có sẵn, bằng phép thay
%
% $$s = \frac{2}{T}\cdot\frac{1 - z^{-1}}{1 + z^{-1}}$$
%
% Phép này ánh xạ nửa trái mặt phẳng $s$ vào trong đường tròn đơn vị, nên bộ
% lọc tương tự ổn định thì bộ lọc số cũng ổn định. Nhược điểm: trục tần số bị
% bẻ cong theo $\Omega = \frac{2}{T}\tan(\omega/2)$, nên phải *tiền méo*
% (prewarping) để tần số trung tâm rơi đúng chỗ.
%
% *Lượng tử hoá hệ số.* Trên phần cứng thật, hệ số lưu bằng số nguyên hữu hạn
% bit nên bị làm tròn, làm điểm cực dịch chuyển. Bộ lọc Q cao có cực sát đường
% tròn đơn vị, chỉ cần dịch nhẹ ra ngoài là *mất ổn định*.
%
% Bảng dưới quét $r$ từ 0.99 đến 0.9999 và số bit từ 16 xuống 8. Kết luận rút
% ra được: *bộ lọc của dự án ($r = 0.99$) an toàn ngay cả ở 8 bit*, nhưng nếu
% ai đó tăng $r$ để dải hẹp hơn thì bộ lọc mất ổn định rất nhanh. Thêm một lý
% do nữa để không đụng vào giá trị 0.99.

fprintf('Bộ lọc %d Hz. Dấu ! nghĩa là |cực| >= 1 tức MẤT ỔN ĐỊNH.\n\n', f0);
fprintf('%9s %10s   %s\n', 'r', 'BW (Hz)', '|cực| sau lượng tử hoá theo số bit');
fprintf('%9s %10s   %8s %8s %8s %8s\n', '', '', '16 bit','12 bit','10 bit','8 bit');
fprintf('%s\n', repmat('-',1,60));
for rr = [0.99 0.999 0.9999]
    w0 = 2*pi*f0/fs;
    a  = [1  -2*rr*cos(w0)  rr^2];
    fprintf('%9.4f %10.2f  ', rr, (1-rr)*fs/pi);
    for nbit = [16 12 10 8]
        buoc = 2^-(nbit-2);               % hệ số a nằm trong [-2, 2)
        aq   = round(a/buoc)*buoc;
        pmax = max(abs(roots(aq)));
        if pmax >= 1 - 1e-9, dau = '!'; else, dau = ' '; end   % dung dung sai:
        % cuc nam DUNG tren duong tron da la bien on dinh, khong can vuot qua 1
        fprintf(' %7.5f%s', pmax, dau);
    end
    fprintf('\n');
end


%% 8. Thuật toán Goertzel
% DTMF chỉ cần công suất tại *8 tần số biết trước*. FFT tính cả $N$ bin rồi
% bỏ gần hết. Goertzel tính *riêng từng bin cần dùng*, chi phí rất nhỏ.
%
% Với mỗi bin $k$ và khung $x[0..N-1]$:
%
% $$c = 2\cos\!\left(\frac{2\pi k}{N}\right)$$
%
% $$s[n] = x[n] + c\,s[n-1] - s[n-2], \qquad n = 0 \dots N-1, \quad s[-1]=s[-2]=0$$
%
% $$P = s[N-1]^2 + s[N-2]^2 - c\,s[N-1]\,s[N-2] \;=\; |X[k]|^2$$
%
% Mỗi mẫu chỉ có *một phép nhân số thực*.

%%
% *8.1 Dẫn giải công thức - 6 bước*
%
% Đặt $\omega = 2\pi k/N$ và $W = e^{j\omega}$.
%
% *Bước 1 - viết DFT thành tích luỹ đệ quy.* Định nghĩa
%
% $$y[n] = x[n] + W y[n-1], \qquad y[-1] = 0$$
%
% Mở ra: $y[0] = x[0]$, $y[1] = x[1] + Wx[0]$, $y[2] = x[2] + Wx[1] + W^2x[0]$, ...
%
% *Bước 2 - chứng minh $y[N-1]$ cho ra $X[k]$.*
%
% $$y[N-1] = \sum_{m=0}^{N-1} x[m]W^{N-1-m} = W^{N-1}\sum_m x[m]W^{-m} = W^{N-1}X[k]$$
%
% Vì $W^N = e^{j2\pi k} = 1$ nên $W^{N-1}$ có độ lớn 1, suy ra $|y[N-1]| = |X[k]|$.
%
% *Bước 3 - nhận xét.* Đây là bộ lọc IIR bậc 1 $H_1(z) = 1/(1 - Wz^{-1})$
% nhưng *hệ số phức*, mỗi bước phải nhân số phức, tốn kém.
%
% *Bước 4 - khử phần ảo.* Nhân cả tử và mẫu với liên hợp $(1 - W^*z^{-1})$:
%
% $$(1 - Wz^{-1})(1 - W^*z^{-1}) = 1 - 2\cos(\omega)z^{-1} + z^{-2}$$
%
% Mẫu số giờ *toàn hệ số thực*.
%
% *Bước 5 - tách hai tầng.* Phần mẫu số thành phương trình sai phân hệ số thực
% $s[n] = x[n] + 2\cos(\omega)s[n-1] - s[n-2]$; phần tử số chỉ áp dụng *một lần
% ở cuối*: $y[N-1] = s[N-1] - e^{-j\omega}s[N-2]$.
%
% *Bước 6 - lấy bình phương độ lớn.* Đặt $s_1 = s[N-1]$, $s_2 = s[N-2]$:
%
% $$y[N-1] = (s_1 - \cos\omega\, s_2) + j\sin\omega\, s_2$$
%
% $$|y|^2 = s_1^2 - 2\cos\omega\, s_1 s_2 + \cos^2\!\omega\, s_2^2 + \sin^2\!\omega\, s_2^2
%         = s_1^2 + s_2^2 - 2\cos\omega\, s_1 s_2$$
%
% Với $c = 2\cos\omega$ ta được đúng công thức $P$ ở trên.

%%
% *8.2 Tính tay: N = 16, k = 3*
%
% Bảng dưới đây là bảng phải tự tính được bằng tay hoặc bằng Excel. $c = 2\cos(2\pi \cdot 3/16) \approx 0.7654$.
% Kết quả cuối: $s[15] = 0$, $s[14] = -8$, nên $P = 0^2 + (-8)^2 - c \cdot 0 \cdot (-8) = 64$.
%
% Để ý $|s[n]|$ lớn dần - bộ lọc đang *cộng hưởng* vì tín hiệu vào đúng tần
% số của nó.

N = 16; k = 3;
n = 0:N-1;
x = cos(2*pi*k*n/N);
c = 2*cos(2*pi*k/N);
fprintf('c = 2*cos(2*pi*3/16) = %.6f\n\n', c);
fprintf('%4s %10s %10s %10s %12s\n','n','x[n]','s[n-1]','s[n-2]','s[n]');
fprintf('%s\n', repmat('-',1,50));
s1 = 0; s2 = 0;
for i = 1:N
    s = x(i) + c*s1 - s2;
    fprintf('%4d %10.4f %10.4f %10.4f %12.4f\n', i-1, x(i), s1, s2, s);
    s2 = s1; s1 = s;
end
Xf = fft(x);
fprintf('\ns[15] = %.4f,  s[14] = %.4f\n', s1, s2);
fprintf('P = %.6f   |X[3]|^2 (FFT) = %.6f   lý thuyết = %.6f\n', ...
        s1^2 + s2^2 - c*s1*s2, abs(Xf(k+1))^2, (N/2)^2);

%%
% *8.3 Goertzel dưới góc nhìn bộ lọc*
%
% $s[n] = x[n] + 2\cos(\omega)s[n-1] - s[n-2]$ là bộ lọc IIR bậc 2 có mẫu số
% $1 - 2\cos(\omega)z^{-1} + z^{-2}$. So với bộ cộng hưởng ở mục 7.1, đây
% chính là trường hợp *$r = 1$*: hai cực nằm *đúng trên* đường tròn đơn vị.
%
% Theo lý thuyết đó là *biên ổn định*, đầu ra có thể lớn vô hạn. Goertzel vẫn
% dùng được vì chỉ chạy đúng $N$ mẫu rồi *khởi tạo lại* $s = 0$ cho khung sau,
% nên giá trị không kịp phân kỳ.

fprintf('Cực của Goertzel (r = 1) so với bộ cộng hưởng (r = 0.99):\n');
w0 = 2*pi*697/fs;
fprintf('  Goertzel    : |cực| = %.6f  -> biên ổn định\n', abs(roots([1 -2*cos(w0) 1])));
fprintf('  Cộng hưởng  : |cực| = %.6f  -> ổn định\n', max(abs(roots([1 -2*0.99*cos(w0) 0.99^2]))));

%%
% Đoạn dưới chạy Goertzel *không reset* qua 20 khối 205 mẫu và đo biên độ đỉnh
% của $|s[n]|$ trong từng khối. Chạy hai tín hiệu để thấy rõ sự khác nhau:
%
% * *đúng tần số bin* (702.44 Hz, ứng với $k = 18$): biên độ tăng *tuyến tính*,
%   khối 16 gấp đúng 16 lần khối 1 - đây là biểu hiện của cực nằm trên đường
%   tròn đơn vị, đầu ra phân kỳ.
% * *lệch bin 5.4 Hz* (697 Hz thật): biên độ *dao động phách* quanh một giá trị
%   hữu hạn, không phân kỳ.
%
% Vì tần số DTMF thật hầu như không bao giờ rơi đúng tâm bin, trên thực tế
% Goertzel không reset sẽ không nổ ngay - nhưng đó là *may*, không phải thiết
% kế. Luôn reset $s_1 = s_2 = 0$ ở đầu mỗi khung.

N = 205;
kb = round(N*697/fs);
cc = 2*cos(2*pi*kb/N);
fprintf('k = %d -> tần số tâm bin = %.2f Hz\n\n', kb, kb*fs/N);
fprintf('%-22s %s\n', 'Tín hiệu vào', 'đỉnh |s[n]| ở khối 1, 2, 4, 8, 16');
fprintf('%s\n', repmat('-',1,70));
for tc = 1:2
    if tc == 1, fsig = kb*fs/N; nhan = 'đúng bin 702.44 Hz';
    else,       fsig = 697;     nhan = 'lệch bin, 697 Hz';   end
    nLong = 0:(16*N-1);
    xLong = sin(2*pi*fsig*nLong/fs);
    s1 = 0; s2 = 0; dinhKhoi = zeros(1,16); cur = 0;
    for i = 1:numel(xLong)
        s = xLong(i) + cc*s1 - s2; s2 = s1; s1 = s;
        cur = max(cur, abs(s));
        if mod(i, N) == 0, dinhKhoi(i/N) = cur; cur = 0; end
    end
    fprintf('%-22s', nhan);
    fprintf(' %9.1f', dinhKhoi([1 2 4 8 16]));
    fprintf('\n');
end
fprintf('\nDòng 1 tăng tuyến tính (phân kỳ), dòng 2 dao động phách (hữu hạn).\n');

%%
% *8.4 Áp vào tín hiệu thật - vector E 8 phần tử*
%
% Đây là dạng dữ liệu mà *cả ba bộ giải mã đều phải tạo ra*, để dùng chung
% một hàm quyết định:
%
%    E(1:4) = công suất tại 697, 770, 852, 941 Hz    (nhóm hàng)
%    E(5:7) = công suất tại 1209, 1336, 1477 Hz      (nhóm cột)
%    E(8)   = công suất tại bin hài bậc 2 của đỉnh mạnh nhất
%
% Bin hài: $k_{hai} = \min(2k_{dinh},\ \lfloor N/2 \rfloor)$.

N = 205;
n = 0:N-1;
x = sin(2*pi*770*n/fs) + sin(2*pi*1336*n/fs);      % phím "5", biên độ 1 mỗi tone
ks = round(N*FALL/fs);
E = zeros(8,1);
for j = 1:7
    E(j) = goertzelPower(x, ks(j), N);
end
[~, d] = max(E(1:7));
kh = min(2*ks(d), floor(N/2));
E(8) = goertzelPower(x, kh, N);

fprintf('ks   = %s,  k_hài = %d\n', mat2str(ks), kh);
fprintf('%9s %10s %14s\n','bin','f (Hz)','E');
for j = 1:7, fprintf('%9d %10d %14.1f\n', ks(j), FALL(j), E(j)); end
fprintf('%9d %10s %14.1f\n', kh, 'hài bậc 2', E(8));
fprintf('\nHai đỉnh rõ ràng ở 770 và 1336 Hz. Các bin khác khác 0 - đó là rò rỉ phổ.\n');

%%
% *8.5 Chi phí tính toán*
%
%    Phương pháp                        Số phép nhân mỗi khung
%    Goertzel, 8 bin x 205 mẫu          8 x 205 = 1 640 phép nhân thực
%    FFT 256 điểm                       (N/2)*log2(N) = 1 024 phép nhân phức
%                                       ~ 4 096 phép nhân thực
%    Ngân hàng 8 bộ lọc IIR bậc 2       ~ 3 280
%
% Goertzel chỉ có lợi khi số tần số cần đo *ít*. Cần nhiều bin thì FFT rẻ hơn.
% Điểm hoà vốn nằm ở khoảng $\log_2 N$ bin.

Ng = 8*205;
Nf = (256/2)*log2(256)*4;
Nb = 8*205*2;
fprintf('Goertzel 8 bin  : %6d phép nhân thực\n', Ng);
fprintf('FFT 256 điểm    : %6d phép nhân thực (quy đổi 1 phức = 4 thực)\n', Nf);
fprintf('Ngân hàng lọc   : %6d phép nhân thực (2 phép nhân/mẫu/bộ lọc)\n', Nb);
fprintf('\nGoertzel rẻ hơn FFT %.1f lần, rẻ hơn ngân hàng lọc %.1f lần.\n', Nf/Ng, Nb/Ng);
fprintf('Điểm hoà vốn với FFT %d điểm: khoảng %d bin.\n', 256, round(log2(256)));


%% 9. Ngân hàng bộ lọc
% Phương pháp thứ ba, tư duy theo miền thời gian thay vì miền tần số.
%
%                +-- BPF  697 --> y1[n] --> năng lượng mỗi khung --> E(1,i)
%                +-- BPF  770 --> y2[n] --> ...                  --> E(2,i)
%    y[n] -------+-- ...
%                +-- BPF 1477 --> y7[n] --> ...                  --> E(7,i)
%                +-- BPF hài  --> y8[n] --> ...                  --> E(8,i)
%
% # Thiết kế 8 bộ lọc thông dải hẹp theo mục 7.1, $r = 0.99$.
% # *Lọc cả tín hiệu một lần*: |y_j = filter(b_j, a_j, y)|.
% # Chia khung theo mục 6, tính $E(j,i) = \sum y_j[\text{khung } i]^2$.
% # Đưa cột $E(:,i)$ vào cùng hàm quyết định với hai phương pháp kia.
%
% *Bước 2 là chỗ dễ sai nhất.* Không được lọc riêng từng khung: mỗi lần bắt
% đầu lại, bộ lọc IIR cần thời gian quá độ, làm năng lượng đầu khung sai.
% Đoạn code dưới đo chính xác sai lệch đó.

N = 205;
nAll = 0:(10*N-1);
y = sin(2*pi*770*nAll/fs) + sin(2*pi*1336*nAll/fs);
[b, a] = boLoc(770, 0.99, fs);

yLienTuc = filter(b, a, y);                  % ĐÚNG: lọc cả tín hiệu một lần
fprintf('%7s %16s %16s %12s\n','khung','lọc liên tục','lọc từng khung','sai lệch');
fprintf('%s\n', repmat('-',1,56));
for i = 1:5
    idx = (i-1)*N + (1:N);
    E_dung = sum(yLienTuc(idx).^2);
    E_sai  = sum(filter(b, a, y(idx)).^2);   % SAI: reset bộ lọc mỗi khung
    fprintf('%7d %16.1f %16.1f %11.1f%%\n', i, E_dung, E_sai, (E_sai-E_dung)/E_dung*100);
end
fprintf('\nĐọc bảng: khung 1 hai cách cho kết quả GIỐNG NHAU, vì cả hai đều bắt đầu\n');
fprintf('từ trạng thái nghỉ. Từ khung 2 trở đi, cách sai thiếu khoảng 60%% năng lượng -\n');
fprintf('bộ lọc bị ép quay về quá độ ở mỗi khung nên không bao giờ lên hết biên độ.\n');
fprintf('Hệ quả: ngưỡng đặt theo khung ổn định sẽ loại nhầm gần như mọi khung.\n');


%% 10. Luật quyết định
% Cả ba bộ giải mã đều tạo ra một vector $E$ kích thước 8×1 cho mỗi khung, rồi
% đưa vào *cùng một hàm* quyết định. Nhờ vậy việc so sánh ba phương pháp mới
% công bằng - khác biệt đo được là khác biệt của thuật toán trích đặc trưng,
% không phải của luật quyết định.
%
% Gọi |rowPeak| / |rowPeak2| là đỉnh lớn nhất / lớn nhì trong $E(1{:}4)$;
% |colPeak| / |colPeak2| tương tự trong $E(5{:}7)$.
%
%    #   Điều kiện              Công thức                        Ngưỡng        Trượt
%    1   Đỉnh hàng nổi trội     10*log10(rowPeak/rowPeak2)       >= 6 dB       'level'
%    2   Đỉnh cột nổi trội      10*log10(colPeak/colPeak2)       >= 6 dB       'level'
%    3   Twist                  10*log10(colPeak/rowPeak)        [-8, +4] dB   'twist'
%    4   Tỉ lệ năng lượng       (xem ghi chú bên dưới)           >= 70%        'level'
%    5   Hài bậc 2 nhỏ          E(8) <= 0.5*min(rowPeak,colPeak)               'harmonic'
%
% Kiểm tra lần lượt; gặp điều kiện trượt đầu tiên thì dừng ngay và gán
% |rowIdx = colIdx = 0|. Qua hết thì |reject = 'none'|.
%
% Ý nghĩa: điều kiện 1 và 2 đòi mỗi nhóm phải có *đúng một* tần số nổi bật -
% hai tần số cùng mạnh thì không biết là phím nào. Điều kiện 3 đòi hai tone có
% mức tương đương. Điều kiện 4 đòi năng lượng tập trung ở các tần số DTMF chứ
% không rải khắp phổ. Điều kiện 5 chống tiếng nói.

E1 = [1 8 1 1  1 9 1  0.1]';
fprintf('--- Khung được chấp nhận: E = %s ---\n', mat2str(E1'));
inQuyetDinh(E1, KEYS);

E2 = [5 5.5 1 1  1 9 1  0.1]';
fprintf('\n--- Khung bị từ chối: E = %s ---\n', mat2str(E2'));
inQuyetDinh(E2, KEYS);

fprintf('\n--- Với số liệu thật của phím "5" ở mục 8.4 ---\n');
inQuyetDinh(E, KEYS);

%%
% *10.1 Những điểm CHƯA CHỐT - tổ đặc tả phải quyết*
%
% Đây không phải lý thuyết mà là *rủi ro dự án*. Ghi ra để không ai cài đặt
% theo cách hiểu riêng của mình.
%
% # *Định nghĩa "70% năng lượng" đang có hai cách hiểu.*
%   Cách A: |(rowPeak+colPeak)/sum(E)| - so với tổng 8 bin.
%   Cách B: tổng 8 bin chia cho năng lượng toàn khung (dùng Parseval).
%   Hai cách cho ra số khác nhau, xem đoạn code dưới. *Phải chọn một.*
% # *Ngưỡng hài 0.5* mới chỉ có trong |docs/goertzel.md|, chưa có ở file khác.
% # *|info.conf|* được CONTRACTS.md yêu cầu nhưng chưa có công thức.
% # *Khung im lặng hoàn toàn:* $E$ toàn 0 làm |10*log10(0/0)| ra |NaN|. Mọi so
%   sánh với |NaN| đều ra |false| nên khung bị loại - đúng kết quả nhưng *sai
%   lý do*. Luật chưa có ngưỡng năng lượng tuyệt đối, nên một khung chỉ có
%   nhiễu rất nhỏ vẫn có thể lọt qua.

rp = max(E(1:4));  cp = max(E(5:7));
cachA = (rp + cp)/sum(E);
cachB = 2*sum(E(1:7))/(N*sum(x.^2));
fprintf('Cách A: (rowPeak+colPeak)/sum(E)        = %.1f %%\n', cachA*100);
fprintf('Cách B: 2*sum(E(1:7))/(N*sum(x.^2))     = %.1f %%\n', cachB*100);
fprintf('Chênh nhau %.1f điểm phần trăm - cùng một khung, cùng ngưỡng 70%%.\n', ...
        abs(cachA-cachB)*100);

Ezero = zeros(8,1);
fprintf('\nKhung im lặng: 10*log10(0/0) = %s  -> mọi so sánh ra false\n', ...
        mat2str(10*log10(max(Ezero(1:4))/max(Ezero(1:4)))));


%% 11. Từ khung đến chuỗi phím
% Sau mục 10, mỗi khung cho một kết quả: một phím, hoặc "không có phím".
%
%    Khung:   1    2    3    4    5    6    7    8    9   10
%    Kết quả: 5    5    5    5    -    -    1    1    1    -
%                                    | gộp
%    keys = "51"
%
% *Chống dội (debounce):* gộp các khung liên tiếp cùng phím thành *một* ký
% tự; khung "không có phím" đóng vai trò ranh giới giữa hai ký tự.
%
% Ba cái bẫy khi cài đặt:
%
% # *Hai phím giống nhau liền nhau* (chuỗi |"55"|) chỉ tách được nếu giữa
%   chúng có *ít nhất một khung bị từ chối*. Khoảng nghỉ 50 ms = 400 mẫu; với
%   khung 205 mẫu nối tiếp thì tuỳ vị trí, có thể *không khung nào nằm trọn*
%   trong khoảng nghỉ. Khung vắt ngang tone và khoảng nghỉ vẫn có thể được
%   nhận là phím, làm |"55"| bị gộp thành |"5"|. *Phải test riêng ca này.*
% # *Khung vắt qua hai phím khác nhau* chứa hỗn hợp hai cặp tần số, thường bị
%   từ chối ở điều kiện 1 hoặc 2; nếu lọt thì ra ký tự lạ.
% # Có thể yêu cầu một phím xuất hiện tối thiểu $m$ khung liên tiếp mới được
%   nhận, để chống nhiễu thoáng qua. *Dự án chưa chốt $m$.*

% Đoạn dưới quét một chuỗi 12 phím và hỏi: *khoảng nghỉ thứ mấy không chứa
% trọn một khung nào?* Đó chính là chỗ hai phím giống nhau sẽ bị gộp nhầm.

nTone = round(0.100*fs); nNghi = round(0.050*fs); frameN = 205;
fprintf('tone %d mẫu, nghỉ %d mẫu, khung %d mẫu\n', nTone, nNghi, frameN);
fprintf('Chu kỳ một phím = %d mẫu; %d chia cho hop = 205 dư %d -> khung trôi dần.\n\n', ...
        nTone+nNghi, nTone+nNghi, mod(nTone+nNghi, 205));

for hop = [205 128]
    hong = [];
    fprintf('--- hop = %d ---\n', hop);
    for phim = 1:12
        bd = phim*nTone + (phim-1)*nNghi;
        kt = bd + nNghi;
        co = false;
        for i = 1:300
            i1 = (i-1)*hop + 1;  i2 = i1 + frameN - 1;
            if i1 > bd && i2 <= kt, co = true; break; end
        end
        if ~co, hong(end+1) = phim; end %#ok<AGROW>
    end
    if isempty(hong)
        fprintf('  Mọi khoảng nghỉ đều chứa trọn ít nhất một khung -> an toàn.\n');
    else
        fprintf('  Khoảng nghỉ KHÔNG chứa trọn khung nào: sau phím %s\n', mat2str(hong));
        fprintf('  -> %d/12 vị trí. Hai phím giống nhau rơi đúng chỗ này sẽ bị gộp.\n', numel(hong));
    end
end

fprintf('\nĐây là loại lỗi nguy hiểm nhất: nó chỉ xảy ra ở MỘT vị trí trong mười hai,\n');
fprintf('nên test ngẫu nhiên rất dễ bỏ sót, và khi xảy ra thì im lặng nuốt mất một ký tự.\n');
fprintf('Hai cách xử lý: dùng hop nhỏ hơn (khung chồng lấp), hoặc thêm luật\n');
fprintf('"phím phải xuất hiện tối thiểu m khung liên tiếp" rồi đếm số khung để tách.\n');


%% 12. Đánh giá kết quả
% *Độ chính xác* - tỉ lệ ký tự giải đúng sau khi căn chỉnh hai chuỗi.
%
% *Khoảng cách Levenshtein* - số phép chèn, xoá, thay ít nhất để biến chuỗi
% này thành chuỗi kia. Tính bằng quy hoạch động:
%
% $$d(i,0) = i, \qquad d(0,j) = j$$
%
% $$d(i,j) = \min\big( d(i-1,j)+1,\; d(i,j-1)+1,\; d(i-1,j-1) + [A_i \neq B_j] \big)$$
%
% Ba số hạng lần lượt là: xoá, chèn, thay (0 nếu hai ký tự trùng).
%
% *Ma trận nhầm lẫn 12×12* - phần tử $(i,j)$ là số lần phím thật $i$ bị giải
% thành phím $j$; đường chéo là số lần đúng. Dự đoán: các cặp hay nhầm là phím
% *cùng hàng hoặc cùng cột*, vì chỉ sai một trong hai tần số.
%
% *Đường cong accuracy–SNR* - chạy cả ba bộ giải mã ở nhiều mức SNR rồi vẽ
% chung một đồ thị, để thấy phương pháp nào chịu nhiễu tốt hơn.

A = '123'; B = '1283';
[d, D] = levenshtein(A, B);
fprintf('Bảng quy hoạch động cho A = "%s", B = "%s":\n\n', A, B);
fprintf('%6s', '');  fprintf('%6s', '""');
for j = 1:numel(B), fprintf('%6c', B(j)); end
fprintf('\n');
for i = 0:numel(A)
    if i == 0, fprintf('%6s', '""'); else, fprintf('%6c', A(i)); end
    fprintf('%6d', D(i+1,:)); fprintf('\n');
end
fprintf('\nKhoảng cách = %d (một phép chèn ký tự "8")\n', d);

fprintf('\nCác cặp phím dự đoán hay nhầm (chung một tần số):\n');
dem = 0;
for i1 = 1:4, for j1 = 1:3, for i2 = 1:4, for j2 = 1:3
    if (i1 < i2 && j1 == j2) || (i1 == i2 && j1 < j2)
        dem = dem + 1;
    end
end, end, end, end
fprintf('  %d cặp cùng hàng hoặc cùng cột trên tổng %d cặp phím.\n', dem, 12*11/2);


%% 13. Bảng thông số chốt
%
%    ĐẠI LƯỢNG                      GIÁ TRỊ              NGUỒN / LÝ DO
%    ---------------------------------------------------------------------------
%    fs                             8000 Hz              chuẩn mạng điện thoại
%    Nyquist                        4000 Hz              fs/2
%    Tần số hàng                    697 770 852 941 Hz   ITU-T Q.23
%    Tần số cột                     1209 1336 1477 Hz    ITU-T Q.23 (KHÔNG dùng 1633)
%    Khoảng cách nhỏ nhất           73 Hz                697 và 770
%    Tone / nghỉ                    100 ms / 50 ms       CONTRACTS.md
%    Tone tối thiểu chuẩn           40 ms                ITU-T Q.24
%    Khung Goertzel / lọc           N = 205, hop = 205   lệch bin max 1.36% < 1.5%
%    Khung FFT                      N = 256, hop = 128   lũy thừa 2, chồng 50%
%    Cửa sổ                         Hamming cho FFT      Goertzel không dùng cửa sổ
%    Bin Goertzel k                 18 20 22 24 31 34 38 k = round(N*f0/fs)
%    Bin thứ 8                      hài bậc 2            min(2*k_đỉnh, floor(N/2))
%    r bộ lọc                       0.99                 BW 25.5 Hz; 5*tau 62 ms < 100 ms
%    Băng thông bộ lọc              ~25.5 Hz             (1-r)*fs/pi
%    Q                              27.4 .. 58.0         f0/BW
%    Dung sai tần số                nhận <=1.5%, từ chối >=3.5%   ITU-T Q.24
%    Twist                          thuận <=4 dB, nghịch <=8 dB   ITU-T Q.24
%    Ngưỡng đỉnh nổi trội           >= 6 dB              docs/goertzel.md
%    Ngưỡng tỉ lệ năng lượng        >= 70%               CHƯA CHỐT định nghĩa
%    Ngưỡng hài                     E(8) <= 0.5*min(rp,cp)        chỉ có trong goertzel.md
%
% *Ba con số phải thuộc lòng:* 73 Hz (khoảng cách nhỏ nhất), 205 mẫu (khung),
% 0.99 (bán kính cực).
%
%% Bốn lập luận đáng viết vào báo cáo
%
% Lý thuyết chép từ giáo trình thì ai cũng có. Bốn chỗ dưới đây là chỗ *có
% lập luận riêng của nhóm*, dẫn từ ràng buộc bài toán ra tham số thiết kế:
%
% # *Vì sao N = 205 chứ không phải số khác.* Không phải vì "đủ nhỏ hơn 73 Hz",
%   mà vì độ lệch bin lớn nhất là 1.36%, nằm dưới dung sai nhận 1.5% của
%   ITU-T. Chọn N khác thì chính bộ giải mã tự đẩy tần số ra ngoài vùng
%   chấp nhận. Xem mục 5.4.
% # *Vì sao r = 0.99 chứ không lớn hơn.* Vì $5\tau$ phải nhỏ hơn độ dài tone
%   100 ms. $r = 0.995$ cần 124.7 ms nên hỏng hoàn toàn. $r = 0.99$ là *giới
%   hạn trên*, không phải lựa chọn tuỳ ý. Xem mục 7.2.
% # *Vì sao phải lọc cả tín hiệu trước rồi mới chia khung.* Vì quá độ của bộ
%   lọc IIR làm sai năng lượng khung đầu. Mục 9 đo được sai lệch cụ thể.
% # *Vì sao lọc dải hẹp chịu nhiễu tốt đến vậy.* Nhiễu trắng trải đều trên
%   0–4000 Hz, mỗi bộ lọc chỉ mở cửa sổ 25.5 Hz nên chỉ hứng khoảng
%   $25.5/4000 \approx 0.6\%$ công suất nhiễu. Đây là con số giải thích được
%   mọi kết quả ở đường cong accuracy–SNR.

fprintf('Tỉ lệ công suất nhiễu mà một bộ lọc hứng: %.2f %% của tổng nhiễu băng gốc.\n', ...
        25.5/(fs/2)*100);
fprintf('Độ lợi xử lý lý thuyết: %.1f dB\n', 10*log10((fs/2)/25.5));


%% Các hàm dùng chung
% MATLAB bắt buộc đặt hàm cục bộ ở *cuối* file script. Đừng xoá phần này.

function w = hammingTay(N)
% Cửa sổ Hamming, véc-tơ cột. Tương đương hamming(N) của Signal Processing Toolbox.
    n = (0:N-1)';
    w = 0.54 - 0.46*cos(2*pi*n/(N-1));
end

function P = goertzelPower(x, k, N)
% |X[k]|^2 theo thuật toán Goertzel. Chỉ dùng số thực, 1 phép nhân mỗi mẫu.
    c  = 2*cos(2*pi*k/N);
    s1 = 0; s2 = 0;
    for n = 1:N
        s  = x(n) + c*s1 - s2;
        s2 = s1;
        s1 = s;
    end
    P = s1^2 + s2^2 - c*s1*s2;
end

function H = dapUngTanSo(b, a, f, fs)
% Đáp ứng tần số H(e^{jw}) của bộ lọc bậc 2, tính thẳng bằng công thức.
% Tương đương freqz(b, a, f, fs) nhưng không cần Signal Processing Toolbox.
    z = exp(1j*2*pi*f/fs);
    H = (b(1) + b(2)./z + b(3)./z.^2) ./ (a(1) + a(2)./z + a(3)./z.^2);
end

function [b, a] = boLoc(f0, r, fs)
% Bộ cộng hưởng bậc 2 tại f0, đã chuẩn hoá để |H(f0)| = 1.
    if nargin < 2, r  = 0.99; end
    if nargin < 3, fs = 8000; end
    w0 = 2*pi*f0/fs;
    b  = [1 0 -1];
    a  = [1  -2*r*cos(w0)  r^2];
    b  = b / abs(dapUngTanSo(b, a, f0, fs));
end

function [d, D] = levenshtein(A, B)
% Khoảng cách Levenshtein và bảng quy hoạch động đầy đủ.
    m = numel(A); n = numel(B);
    D = zeros(m+1, n+1);
    D(:,1) = (0:m)';
    D(1,:) =  0:n;
    for i = 1:m
        for j = 1:n
            thay  = D(i,j) + (A(i) ~= B(j));
            D(i+1,j+1) = min([D(i,j+1)+1, D(i+1,j)+1, thay]);
        end
    end
    d = D(m+1, n+1);
end

function inQuyetDinh(E, KEYS)
% Chạy đủ 5 điều kiện của luật quyết định và in ra từng bước.
    row = E(1:4); col = E(5:7);
    [rp, ri] = max(row);  rs = max(row([1:ri-1 ri+1:end]));
    [cp, ci] = max(col);  cs = max(col([1:ci-1 ci+1:end]));

    dRow  = 10*log10(rp/rs);
    dCol  = 10*log10(cp/cs);
    twist = 10*log10(cp/rp);
    ratio = (rp + cp)/sum(E);
    harm  = E(8) <= 0.5*min(rp, cp);

    reject = 'none';
    fprintf('  1. đỉnh hàng  %7.2f dB  (>= 6)      %s\n', dRow, dat(dRow >= 6));
    if dRow < 6, reject = 'level'; end
    fprintf('  2. đỉnh cột   %7.2f dB  (>= 6)      %s\n', dCol, dat(dCol >= 6));
    if strcmp(reject,'none') && dCol < 6, reject = 'level'; end
    fprintf('  3. twist      %7.2f dB  ([-8, +4])  %s\n', twist, dat(twist >= -8 && twist <= 4));
    if strcmp(reject,'none') && (twist < -8 || twist > 4), reject = 'twist'; end
    fprintf('  4. tỉ lệ E    %7.2f %%   (>= 70)     %s\n', ratio*100, dat(ratio >= 0.70));
    if strcmp(reject,'none') && ratio < 0.70, reject = 'level'; end
    fprintf('  5. hài bậc 2  %7.2f     (<= %.2f)   %s\n', E(8), 0.5*min(rp,cp), dat(harm));
    if strcmp(reject,'none') && ~harm, reject = 'harmonic'; end

    if strcmp(reject, 'none')
        fprintf('  => CHẤP NHẬN: hàng %d, cột %d -> phím "%c"\n', ri, ci, KEYS(ri, ci));
    else
        fprintf('  => TỪ CHỐI: reject = ''%s'', rowIdx = colIdx = 0\n', reject);
    end
end

function s = dat(tf)
% Nhãn đạt / không đạt cho bảng in ra.
    if tf, s = 'đạt'; else, s = 'KHÔNG ĐẠT'; end
end
