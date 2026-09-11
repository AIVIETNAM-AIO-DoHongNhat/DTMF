function [rowIdx, colIdx, conf, reject] = dtmf_decide(E, opt)
%DTMF_DECIDE Luật quyết định chung: từ 8 giá trị công suất -> phím bấm.
%   [ROWIDX, COLIDX, CONF, REJECT] = DTMF_DECIDE(E) áp dụng luật quyết định
%   cho MỘT khung với các ngưỡng mặc định.
%
%   [...] = DTMF_DECIDE(E, Name, Value) thay đổi ngưỡng qua các cặp
%   tên–giá trị.
%
%   Đầu vào:
%       E - 8×1 double, công suất của một khung tại
%           [697 770 852 941 1209 1336 1477] Hz và hài bậc 2
%           (thứ tự: E(1:4) nhóm hàng, E(5:7) nhóm cột, E(8) hài).
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'peakDb'      - đỉnh phải lớn hơn đỉnh nhì CÙNG NHÓM ít nhất
%                       peakDb [dB] (6).
%       'energyRatio' - tổng công suất 8 bin / năng lượng toàn khung phải
%                       >= tỉ lệ này (0.70).
%       'twistFwdDb'  - twist thuận tối đa, cột mạnh hơn hàng [dB] (4).
%       'twistBwdDb'  - twist nghịch tối đa, hàng mạnh hơn cột [dB] (8).
%
%   Đầu ra:
%       rowIdx - chỉ số hàng 1..4, hoặc 0 nếu không quyết định được.
%       colIdx - chỉ số cột 1..3, hoặc 0 nếu không quyết định được.
%       conf   - độ tin cậy, thuộc [0, 1].
%       reject - char, lý do loại khung:
%                'none'     - chấp nhận;
%                'twist'    - chênh lệch mức cột/hàng vượt giới hạn;
%                'level'    - đỉnh không đủ nổi hoặc năng lượng không đủ;
%                'harmonic' - hài bậc 2 quá lớn (nghi là tiếng nói).
%
%   Quy ước dB: vì E là CÔNG SUẤT, mọi tỉ số được tính bằng
%       10*log10(E_a/E_b)   (tương đương 20*log10 của tỉ số biên độ).
%       Twist = 10*log10(max(E(5:7)) / max(E(1:4))) phải thuộc
%       [-twistBwdDb, twistFwdDb].
%
%   Ghi chú:
%       - Hàm dùng CHUNG cho cả 3 bộ giải mã để bảo đảm cùng một luật
%         quyết định.
%       - Khối arguments chấp nhận E cỡ 8×nFrame nhưng các đầu ra là vô
%         hướng: mỗi lần gọi chỉ truyền MỘT khung, E(:,i).
%
%   Ví dụ (khung sạch, phím '5' = 770 Hz + 1336 Hz; đơn vị tùy ý, chỉ minh
%   họa hình dạng):
%       E = [1 8 1 1  1 9 1  0.1]';
%       [r, c, conf, rej] = dtmf_decide(E)   % -> r = 2, c = 2, rej = 'none'
%
%   Tham khảo:
%       [1] ITU-T Rec. Q.24, "Multifrequency push-button signal
%           reception", 1988.
%       [2] Gói đặc tả #3 (tổ S1) - ngưỡng, twist, kiểm tra hài bậc 2.
%
%   See also dtmf_decode_fft, dtmf_decode_goertzel, dtmf_decode_filterbank.

arguments
    E (8,:) double
    opt.peakDb (1,1) double = 6
    opt.energyRatio (1,1) double = 0.70
    opt.twistFwdDb (1,1) double = 4
    opt.twistBwdDb (1,1) double = 8
end

% TODO(C):
%   1. Tách E(1:4) = nhóm hàng, E(5:7) = nhóm cột, E(8) = công suất hài
%      bậc 2.
%   2. Tìm đỉnh lớn nhất mỗi nhóm; so với đỉnh nhì cùng nhóm:
%      10*log10(dinh1/dinh2) >= opt.peakDb.
%   3. Kiểm tra twist: 10*log10(dinh_cot/dinh_hang) thuộc
%      [-opt.twistBwdDb, opt.twistFwdDb].
%   4. Kiểm tra energyRatio và ngưỡng hài bậc 2 (E(8) nhỏ so với 2 đỉnh).
%      LƯU Ý: energyRatio cần năng lượng toàn khung, hiện CHƯA có trong đầu
%      vào - cần thống nhất với tổ M (thêm tham số, hoặc để bộ giải mã tự
%      chuẩn hóa E). Với Goertzel/FFT, theo định lý Parseval, tỉ lệ năng
%      lượng của một bin k (0 < k < N/2) là 2*|X[k]|^2 / (N*sum(x.^2)).
%   5. Nếu qua hết -> reject = 'none', trả rowIdx/colIdx; ngược lại gán
%      reject tương ứng và rowIdx = colIdx = 0.

rowIdx = 0; colIdx = 0; conf = 0; reject = 'none'; %#ok<NASGU>
error('dtmf_decide:notImplemented', 'TODO: cai dat dtmf_decide (xem Goi dac ta #3).');

end
