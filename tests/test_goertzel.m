function tests = test_goertzel
%TEST_GOERTZEL Unit test cho goertzel_power - ví dụ kiểm chứng trong kế hoạch.
tests = functiontests(localfunctions);
end

function test_knownValue(testCase)
% N = 16, k = 3, x[n] = cos(2*pi*3*n/16) -> P = 64.000000 (xem CONTRACTS.md).
n = 0:15;
x = cos(2*pi*3*n/16);
P = goertzel_power(x, 3, 16);
testCase.verifyEqual(P, 64.0, 'AbsTol', 1e-9);
end

function test_matchesBuiltinGoertzel(testCase)
% So sánh với hàm goertzel() có sẵn của MATLAB (Signal Processing Toolbox)
% trên một tín hiệu ngẫu nhiên; sai số tương đối < 1e-10.
rng(1);                             % Cố định seed để kết quả tái lập được
N = 205; k = 18;                    % k = 18 ứng với ~697 Hz tại fs = 8000 Hz
x = randn(1, N);
Pmine = goertzel_power(x, k, N);
Xbuiltin = goertzel(x(:), k + 1);   % goertzel() dùng chỉ số bin từ 1 (1-based)
Pbuiltin = abs(Xbuiltin)^2;
testCase.verifyEqual(Pmine, Pbuiltin, 'RelTol', 1e-10);
end

function test_badArgumentsThrowNamedErrors(testCase)
% k, N sai và khung thiếu mẫu đều có định danh lỗi riêng, kể cả NaN.
x = ones(1, 205);
testCase.verifyError(@() goertzel_power(x, -1, 205), 'goertzel_power:badK');
testCase.verifyError(@() goertzel_power(x, 2.5, 205), 'goertzel_power:badK');
testCase.verifyError(@() goertzel_power(x, NaN, 205), 'goertzel_power:badK');
testCase.verifyError(@() goertzel_power(x, 18, 0), 'goertzel_power:badN');
testCase.verifyError(@() goertzel_power(x, 18, 204.5), 'goertzel_power:badN');
testCase.verifyError(@() goertzel_power(x(1:100), 18, 205), 'goertzel_power:shortFrame');
end
