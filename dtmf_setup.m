function dtmf_setup()
%DTMF_SETUP Nạp các thư mục mã nguồn của dự án vào MATLAB path.
%   DTMF_SETUP() thêm src/, app/ và tests/ (kèm thư mục con) vào path của
%   phiên MATLAB hiện tại. Chạy một lần sau khi mở MATLAB, trước khi gọi
%   dtmf_generate, dtmf_decode_goertzel, run_all_tests...
%
%   Cách dùng:
%       cd D:\PROJECT\DMTF
%       dtmf_setup
%
%   Ghi chú:
%       Path chỉ tồn tại trong phiên hiện tại, không ghi vào pathdef.m nên
%       không ảnh hưởng các dự án MATLAB khác trên cùng máy.
%
%   See also run_all_tests, dev_harness.

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));
addpath(genpath(fullfile(root, 'app')));
addpath(fullfile(root, 'tests'));

end
