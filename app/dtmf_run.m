function S = dtmf_run(S)
%DTMF_RUN Chạy giải mã theo trạng thái hiện tại của ứng dụng (không vẽ).
%   S = DTMF_RUN(S) gọi bộ giải mã tương ứng với S.method và ghi kết quả
%   vào chính struct trạng thái S.
%
%   Đầu vào / Đầu ra:
%       S - struct trạng thái của DTMFApp, tối thiểu gồm:
%           .y         - 1×N double, tín hiệu đang xét (vào).
%           .fs        - tần số lấy mẫu [Hz] (vào).
%           .method    - char, 'fft' | 'goertzel' | 'filterbank' (vào).
%           .keysHat   - char, chuỗi phím giải mã được (ra).
%           .info      - struct info của hàm giải mã tương ứng (ra).
%           .lastError - char, thông báo lỗi gần nhất, '' nếu không lỗi (ra).
%
%   Ghi chú kiến trúc:
%       Đây là lớp trung gian DUY NHẤT giữa UI và src/ - mọi callback trong
%       DTMFApp.mlapp chỉ gọi hàm này rồi gọi ui_refresh(app), không gọi
%       trực tiếp các hàm trong src/decode.
%
%   See also ui_refresh, dtmf_decode_fft, dtmf_decode_goertzel,
%   dtmf_decode_filterbank.

% TODO(C):
%   switch S.method
%     case 'fft',        [S.keysHat, S.info] = dtmf_decode_fft(S.y, 'fs', S.fs);
%     case 'goertzel',    [S.keysHat, S.info] = dtmf_decode_goertzel(S.y, 'fs', S.fs);
%     case 'filterbank',  [S.keysHat, S.info] = dtmf_decode_filterbank(S.y, 'fs', S.fs);
%   end
% Bọc trong try/catch, ghi lỗi vào S.lastError thay vì để lỗi văng ra UI.

error('dtmf_run:notImplemented', 'TODO: cai dat dtmf_run (dieu phoi 3 bo giai ma).');

end
