function P = goertzel_power(x, k, N)
%GOERTZEL_POWER Công suất tại bin DFT thứ k bằng thuật toán Goertzel
% Đo xem trong một khung tín hiệu có bao nhiêu năng lượng ở đúng một tần số
%   P = GOERTZEL_POWER(X, K, N) tính P = |X[k]|^2, với X[k] là hệ số DFT
%   N điểm của khung X.
%
%   Không tính cả phổ rồi lấy ra một vạch, mà cho khung chạy qua một bộ lọc
%   IIR bậc 2 cộng hưởng đúng tại tần số cần đo. Dưới đây n tính từ 0, x[n]
%   ứng với x(n+1) trong MATLAB.
%
%   Các bước hoạt động:
%       1. Hệ số duy nhất, tính một lần: c = 2*cos(2*pi*k/N).
%       2. Khởi tạo s[-1] = s[-2] = 0.
%       3. Lặp n = 0..N-1: s[n] = x[n] + c*s[n-1] - s[n-2].
%       4. P = s[N-1]^2 + s[N-2]^2 - c*s[N-1]*s[N-2].
%   Mỗi mẫu chỉ tốn một phép nhân thực và không dùng số phức - rẻ hơn FFT khi
%   chỉ cần vài bin (ở đây 8 bin trên tổng số 205).
%
%   Input:
%       x: 1×M double, một khung tín hiệu; chỉ dùng N mẫu đầu, M >= N.
%       k: số nguyên >= 0, chỉ số bin; tần số tương ứng f_k = k*fs/N [Hz].
%       N: số nguyên > 0, độ dài khung [mẫu] (số điểm DFT).
%
%   Output:
%       P: double >= 0, công suất tại bin k.
%
%   Example:
%       n = 0:15;
%       goertzel_power(cos(2*pi*3*n/16), 3, 16)   % 64; lý thuyết X[3] = 8
arguments
    x (1,:) double
    k (1,1) double {mustBeInteger, mustBeNonnegative}
    N (1,1) double {mustBeInteger, mustBePositive}
end

% Help quy định M >= N: thiếu mẫu là lỗi phía gọi, không tự đệm 0.
if numel(x) < N
    error('goertzel_power:shortFrame', ...
        'x chỉ có %d mẫu, cần ít nhất N = %d mẫu.', numel(x), N);
end
x = x(1:N);

c  = 2*cos(2*pi*k/N);       % hằng số, tính một lần ngoài vòng lặp
s1 = 0;                     % s[-1], s[-2]; cục bộ nên tự reset mỗi lần gọi
s2 = 0;

for n = 1:N
    s  = x(n) + c*s1 - s2;
    s2 = s1;                % không được đảo thứ tự hai dòng
    s1 = s;
end

P = s1^2 + s2^2 - c*s1*s2;  % s1 = s[N-1], s2 = s[N-2]

end
