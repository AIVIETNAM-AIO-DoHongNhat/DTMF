function run_all_tests()
%RUN_ALL_TESTS Chạy toàn bộ unit test của dự án DTMF.
%   RUN_ALL_TESTS() thêm src/, app/, tests/ vào path rồi chạy mọi test
%   trong thư mục tests/; báo lỗi nếu có ít nhất một test thất bại.
%
%   Cách dùng (từ bất kỳ thư mục nào, miễn tests/ nằm trên path):
%       run_all_tests
%
%   Yêu cầu: không có test nào FAIL trước khi merge vào nhánh dev.
%
%   See also runtests, test_generate, test_goertzel.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
addpath(genpath(fullfile(root, 'app')));
addpath(fullfile(root, 'tests'));

results = runtests(fullfile(root, 'tests'));
disp(table(results));

nFailed = nnz([results.Failed]);
if nFailed > 0
    error('run_all_tests:failures', '%d test THAT BAI.', nFailed);
else
    fprintf('\n Tat ca %d test PASS.\n', numel(results));
end

end
