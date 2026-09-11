function P = goertzel_power(x, k, N)
%GOERTZEL_POWER Công suất tại bin DFT thứ k bằng thuật toán Goertzel.
%   P = GOERTZEL_POWER(X, K, N) tính P = |X[k]|^2, trong đó X[k] là hệ số
%   DFT N điểm của khung X, bằng bộ lọc IIR bậc 2 (thuật toán Goertzel).
%
%   Đầu vào:
%       x - 1×M double, một khung tín hiệu (chỉ dùng N mẫu đầu, M >= N).
%       k - số nguyên không âm, chỉ số bin; tần số tương ứng
%           f_k = k*fs/N [Hz].
%       N - số nguyên dương, độ dài khung (số điểm DFT).
%
%   Đầu ra:
%       P - double >= 0, công suất tại bin k, P = |X[k]|^2.
%
%   Cơ sở lý thuyết (chỉ số n trong công thức tính từ 0, tức x[n] ứng với
%   x(n+1) trong MATLAB):
%       c    = 2*cos(2*pi*k/N)
%       s[n] = x[n] + c*s[n-1] - s[n-2],   n = 0..N-1,   s[-1] = s[-2] = 0
%       P    = s[N-1]^2 + s[N-2]^2 - c*s[N-1]*s[N-2]
%   Độ phức tạp O(N) cho mỗi bin, chỉ một phép nhân thực mỗi mẫu; hiệu
%   quả hơn FFT khi chỉ cần một số ít bin (ở đây là 8 bin).
%
%   Ví dụ kiểm chứng (N = 16, k = 3, x[n] = cos(2*pi*3*n/16)):
%       n = 0:15; x = cos(2*pi*3*n/16);
%       P = goertzel_power(x, 3, 16);   % P = 64.000000 (sai số < 1e-9)
%       % Đối chiếu lý thuyết: X[3] = N/2 = 8  =>  |X[3]|^2 = 64.
%
%   Tham khảo:
%       [1] G. Goertzel, "An algorithm for the evaluation of finite
%           trigonometric series," Amer. Math. Monthly, vol. 65, no. 1,
%           pp. 34–35, 1958.
%       [2] J. G. Proakis, D. G. Manolakis, Digital Signal Processing:
%           Principles, Algorithms, and Applications, 4th ed., Pearson,
%           2007.
%       [3] Gói đặc tả #4 (tổ S2 + R2).
%
%   See also dtmf_decode_goertzel, goertzel.

arguments
    x (1,:) double
    k (1,1) double {mustBeInteger, mustBeNonnegative}
    N (1,1) double {mustBeInteger, mustBePositive}
end

% TODO(C): cài đặt vòng lặp truy hồi đúng theo công thức ở trên.
% Kiểm chứng bằng ví dụ số và bằng hàm goertzel() có sẵn của MATLAB
% (sai số tương đối < 1e-10) trước khi coi là hoàn thành -
% xem tests/test_goertzel.m.

P = 0; %#ok<NASGU>
error('goertzel_power:notImplemented', 'TODO: cai dat goertzel_power (xem Goi dac ta #4).');

end
