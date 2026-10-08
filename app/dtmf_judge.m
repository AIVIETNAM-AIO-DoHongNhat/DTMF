function J = dtmf_judge(keysTrue, keysHat)
%DTMF_JUDGE Đối chiếu số thật với số giải mã được, từng chữ số một
% Lúc công bố đáp án: chữ số nào đúng, chữ số nào nhầm, sót hay thừa
%   J = DTMF_JUDGE(KEYSTRUE, KEYSHAT) chấm KEYSHAT theo KEYSTRUE bằng
%   dtmf_metrics rồi dọn sẵn mọi thứ giao diện cần để tô từng chữ số.
%   Hàm này KHÔNG bao giờ ném lỗi: sự cố ghi vào J.lastError, giống dtmf_run.
%
%   Đây là lớp trung gian thứ ba giữa giao diện và src/, bên cạnh dtmf_run
%   (giải mã khối) và dtmf_listen (giải mã luồng) - CONTRACTS §2. Màn giám
%   định DTMFForensic gọi nó khi số thật được công bố.
%
%   Các bước hoạt động:
%       1. Đặt mọi trường đầu ra về giá trị rỗng hợp lệ.
%       2. Bỏ dấu cách, dấu chấm, gạch ngang mà người ta hay gõ vào số điện
%          thoại (0912.345.678) - chỉ ở KEYSTRUE, vì đó là chữ người gõ tay.
%       3. m = dtmf_metrics(KEYSTRUE, KEYSHAT): acc, editDist và align, đường
%          căn chỉnh theo đúng luật ưu tiên của §6(g).
%       4. Gắn nhãn từng cột của align: 'dung' hai hàng bằng nhau, 'nham'
%          khác nhau, 'sot' khi hàng 2 là '-', 'thua' khi hàng 1 là '-'.
%
%   Input:
%       keysTrue: char hoặc string, số thật.
%       keysHat: char hoặc string, số bộ giải mã đọc được.
%
%   Output:
%       J: struct 1×1
%          .keysTrue, .keysHat: char 1×K, 1×L, đã làm sạch.
%          .acc, .editDist: như dtmf_metrics.
%          .align: char 2×n, như dtmf_metrics.
%          .op: cellstr 1×n, nhãn từng cột của align.
%          .nDung, .nNham, .nSot, .nThua: số cột mỗi nhãn.
%          .lastError: char, thông báo lỗi; rỗng là blanks(0) tức 1×0.
%
%   Example:
%       J = dtmf_judge('0912', '09912');
%       J.op            % {'dung', 'thua', 'dung', 'dung', 'dung'}
%       J.nThua         % 1

% Bước 1.
J = struct('keysTrue', blanks(0), 'keysHat', blanks(0), 'acc', 0, 'editDist', 0, ...
           'align', blanks(0), 'op', {cell(1, 0)}, ...
           'nDung', 0, 'nNham', 0, 'nSot', 0, 'nThua', 0, 'lastError', blanks(0));
J.align = reshape(J.align, 2, 0);

try
    % Bước 2.
    kt = reshape(char(keysTrue), 1, []);
    kt = kt(~ismember(kt, ' .-'));
    kh = reshape(char(keysHat), 1, []);
    J.keysTrue = kt;
    J.keysHat  = kh;

    % Bước 3.
    m = dtmf_metrics(kt, kh);
    J.acc      = m.acc;
    J.editDist = m.editDist;
    J.align    = m.align;

    % Bước 4.
    a = m.align;
    op = repmat({'dung'}, 1, size(a, 2));
    op(a(1, :) ~= a(2, :)) = {'nham'};
    op(a(2, :) == '-') = {'sot'};
    op(a(1, :) == '-') = {'thua'};
    J.op    = op;
    J.nDung = nnz(strcmp(op, 'dung'));
    J.nNham = nnz(strcmp(op, 'nham'));
    J.nSot  = nnz(strcmp(op, 'sot'));
    J.nThua = nnz(strcmp(op, 'thua'));
catch ME
    J.lastError = ME.message;
end

end
