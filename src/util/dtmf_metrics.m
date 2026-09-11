function m = dtmf_metrics(keysTrue, keysHat)
%DTMF_METRICS Đánh giá độ chính xác của kết quả giải mã DTMF.
%   M = DTMF_METRICS(KEYSTRUE, KEYSHAT) so sánh chuỗi phím giải mã được
%   KEYSHAT với chuỗi nhãn gốc KEYSTRUE.
%
%   Đầu vào:
%       keysTrue - char 1×K, chuỗi phím đúng (nhãn gốc).
%       keysHat  - char 1×L, chuỗi phím hệ thống giải mã được.
%
%   Đầu ra:
%       m - struct:
%           .acc       - tỉ lệ phím đúng, thuộc [0, 1], so sánh theo vị trí
%                        sau khi căn chỉnh hai chuỗi.
%           .editDist  - khoảng cách Levenshtein giữa hai chuỗi (số phép
%                        chèn/xóa/thay tối thiểu).
%           .confusion - 12×12 double, ma trận nhầm lẫn: phần tử (i, j) là
%                        số lần phím thật i được giải mã thành phím j.
%                        Thứ tự phím theo dtmf_table().keys(:) (duyệt theo
%                        cột): '147*2580369#'.
%
%   Ghi chú:
%       Dùng bởi tests/ và Epic E6 (benchmark) để lập bảng so sánh theo SNR.
%
%   Tham khảo:
%       [1] V. I. Levenshtein, "Binary codes capable of correcting
%           deletions, insertions, and reversals," Soviet Physics
%           Doklady, vol. 10, no. 8, pp. 707–710, 1966.
%
%   See also dtmf_table.

arguments
    keysTrue (1,:) char
    keysHat (1,:) char
end

% TODO(C):
%   .acc      : cần căn chỉnh độ dài hai chuỗi (dùng đường truy vết của
%               editDist để căn chỉnh, hoặc so trực tiếp nếu độ dài bằng
%               nhau).
%   .editDist : cài đặt Levenshtein cơ bản bằng quy hoạch động,
%               độ phức tạp O(K*L).
%   .confusion: dùng dtmf_table().map để lấy [r c] của từng ký tự, rồi
%               đổi sang chỉ số trong ma trận 12×12 bằng sub2ind([4 3], r, c).

m = struct('acc', 0, 'editDist', 0, 'confusion', zeros(12, 12)); %#ok<NASGU>
error('dtmf_metrics:notImplemented', 'TODO: cai dat dtmf_metrics.');

end
