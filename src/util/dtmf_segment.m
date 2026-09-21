function seg = dtmf_segment(y, opt)
%DTMF_SEGMENT Chia tín hiệu thành các khung để phân tích phổ
% Cắt tín hiệu dài thành từng mẩu ngắn bằng nhau, mỗi mẩu đo phổ riêng
%   SEG = DTMF_SEGMENT(Y) chia Y thành các khung không chồng lấp dài 205
%   mẫu. Thêm các cặp tên–giá trị bên dưới để đổi cách chia khung.
%
%   Khung thứ i lấy các mẫu y(i1:i2); mốc thời gian theo quy ước THỜI LƯỢNG,
%   tức tEnd - tStart = frameN/fs (xem CONTRACTS.md, quyết định (d)):
%       nFrame = floor((N - frameN)/hop) + 1,   N = numel(y) >= frameN
%       i1 = (i-1)*hop + 1
%       i2 = i1 + frameN - 1
%       tStart = (i1 - 1)/fs
%       tEnd =  i2/fs
%   Khung cuối không đủ frameN mẫu thì bỏ, KHÔNG chèn 0: đệm 0 làm loãng
%   năng lượng khung, khiến dtmf_decide loại nhầm khung đó với nhãn 'level'.
%   Cả 3 bộ giải mã dùng CHUNG hàm này để bảo đảm cùng một cách chia khung -
%   không tự chia khung riêng trong từng hàm giải mã.
%
%   Input:
%       y: 1×N double, tín hiệu cần chia khung.
%
%   Tham số tên–giá trị (mặc định trong ngoặc):
%       'fs': tần số lấy mẫu [Hz] (8000).
%       'frameN': độ dài khung [mẫu] (205); dùng 256 cho bộ giải mã FFT.
%       'hop': bước nhảy giữa hai khung liên tiếp [mẫu] (205). Cố định là
%              205, KHÔNG tự bằng frameN - đổi frameN thì phải truyền hop.
%
%   Output:
%       seg: mảng struct 1×nFrame, rỗng 1×0 khi N < frameN; mỗi phần tử gồm
%            .idx [i1 i2] [mẫu], .tStart [s], .tEnd [s] (t = 0 tại y(1)).
%
%   Example:
%       seg = dtmf_segment(zeros(1, 1000));
%       numel(seg)      % 4
%       seg(1).idx      % [1 205]
%       seg(4).idx      % [616 820] - 180 mẫu cuối không đủ 1 khung, bị bỏ
arguments
    y (1,:) double
    opt.fs (1,1) double = 8000
    opt.frameN (1,1) double = 205
    opt.hop (1,1) double = 205
end

% max(0, ...) chặn nFrame âm khi y ngắn hơn một khung; thiếu nó thì
% repmat(s, 1, -194) vẫn im lặng trả 1×0 - đúng kết quả nhưng sai lý do.
nFrame = max(0, floor((numel(y) - opt.frameN) / opt.hop) + 1);

% Cấp phát một lần. nFrame = 0 rơi đúng vào nhánh này: repmat(s, 1, 0) cho
% struct 1×0 như đặc tả, nên tín hiệu quá ngắn không cần nhánh if riêng.
seg = repmat(struct('idx', [0 0], 'tStart', 0, 'tEnd', 0), 1, nFrame);

for i = 1:nFrame
    i1 = (i-1)*opt.hop + 1;
    i2 = i1 + opt.frameN - 1;

    seg(i).idx = [i1 i2];
    seg(i).tStart = (i1 - 1) / opt.fs;   % trừ 1: chỉ số mẫu từ 1, thời gian từ 0
    seg(i).tEnd =  i2 / opt.fs;
end

end
