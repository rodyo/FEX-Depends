classdef (Sealed) Depends < handle
    
    properties 
        output_file
        dependencies 
        other_conditions % FUTURE WORK
    end
    
    properties (SetAccess = private)
        % Should only be set on construction
        options
    end
    
    properties (Hidden, Access = private)                            
        dependencies_md5
    end
    
    methods
        
        % Constructor        
        function obj = Depends(output_file, dependencies, varargin)
            
            %% Initialize
            
            % Parse and check user input
            ip = inputParser;
            
            ip.addRequired('output_file' , @ischar);
            ip.addRequired('dependencies', @(x) iscellstr(x) || ischar(x));
            
            ip.addParamValue('method', ...
                'date',...
                @(x) any(strcmpi(x, {'md5', 'date'})) );
            
            ip.addParamValue('other_conditions', [], @() true);
                        
            ip.parse(output_file, dependencies, varargin{:});            
            R = ip.Results;
            
            % Assign class data
            obj.output_file      = R.output_file;
            obj.dependencies     = R.dependencies;
            obj.other_conditions = R.other_conditions;           
            obj.options          = rmfield(R, {'output_file'
                                               'dependencies' 
                                               'other_conditions'});
            
        end
                
        % Getters/setters
        function set.output_file(obj, filename)
            if ischar(filename)
                obj.output_file = filename; 
            else
                % TODO: error
            end
        end
        
        function set.dependencies(obj, filenames)
            
            if ~ischar(filenames) && ~iscellstr(filenames)
                % TODO: error
            end
            
            % Check for existence of each dependent file
            if ischar(filenames)
                filenames = {filenames}; end
            for ii = 1:numel(filenames)
                if ~any(exist(filenames{ii},'file')==[2 3 4 6])
                    % TODO: error
                end
                
                % TODO: (Rody Oldenhuis) files might not be unique (MATLAB
                % search path) 
                
            end
            
            obj.dependencies = filenames; 
            
        end
        
        % Main functionality: check whether action is needed
        function tf = actionNeeded(obj)
            
            uf = {'UniformOutput', false};
            tf = true;
            
            % If the output file does not exist, always take action
            if any(exist(obj.output_file,'file') == [2 3 4 6])
                
                % If there are no dependencies, no action is needed
                if isempty(obj.dependencies)
                    tf = false;
                else
                    switch lower(obj.options.method)
                        
                        % If any of the dates of the dependencies is newer than
                        % that of the output file, take action
                        case 'date'
                            
                            % TODO: (Rody Oldenhuis) output file might not be unique
                            
                            out_date = dir(obj.output_file);
                            out_date = datenum(out_date.date);
                            
                            files = cellfun(@(x) dir(x), obj.dependencies, uf{:});
                            
                            empties = cellfun('isempty', files);
                            if any(empties)
                                warning([mfilename ':missing_dependencies'], [...
                                    'Some dependencies can no longer be found; ',...
                                    'trying to proceed without these missing ',...
                                    'dependencies...']);                            
                                files = files(~empties); 
                            end
                            
                            if isempty(files) || all(cellfun('isempty', files))
                                tf = false;                                    
                            else
                                dates = datenum( cellfun(@(x)x.date, files, uf{:}) );                                
                                if all(dates <= out_date)
                                    tf = false; end
                            end
                            
                        case 'md5'
                            
                            new_md5s = cellfun(...
                                @(x) [obj.md5sum(x, 'string') ' ' obj.md5sum(x, 'file')],...
                                obj.dependencies, uf{:});
                            
                            if isequal(new_md5s, obj.dependencies_md5)
                                tf = false;
                            else
                                obj.dependencies_md5 = new_md5s;
                            end
                            
                        otherwise
                            error([mfilename ':internal_error'],....
                                'Unsupported update method: ''%s''.',...
                                obj.options.method);                            
                    end
                end
            end
            
        end
        
    end
    
    methods (Access = private)
        
        function cs = md5sum(str, type)
            
            import java.security.*;
            import java.math.*;
            import java.lang.String;
            
            switch lower(type)
                case 'file'
                    % String equals file content
                    fid = fopen(str, 'r');
                    OC  = onCleanup(@() any(fid==fopen('all')) && fclose(fid));
                    str = fread(fid, inf, '*schar');
                    fclose(fid);
                    
                case 'string'
                    % String equals string given; do nothing. 
                    
                otherwise
                    error(...
                        [mfilename ':invalid_md5_type'],...
                        'Unsupported inoput type: ''%s''.',...
                        type);
            end
            
            % Compute MD5 with Java call
            md   = MessageDigest.getInstance('MD5');
            hash = md.digest(double(str));
            bi   = BigInteger(1, hash);
            cs   = char(String.format('%032x', bi));
            
        end
        
    end
    
end


