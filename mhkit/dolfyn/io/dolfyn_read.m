function ds=dolfyn_read(filename,options)

%%%%%%%%%%%%%%%%%%%%
%     Read a Nortek Signature (.ad2cp) datafile
%     
% Parameters
% ------------
%     filename: string
%         Filename of instrument file to read.
%     userdata: bool or string (optional)
%         true, false, or string of userdata.json filename (default true)
%         Whether to read the '<base-filename>.userdata.json' file.
%     nens: nan, int, or 2-element array (optional)
%         nan (default: read entire file), int, or 2-element tuple 
%         (start, stop) Number of pings to read from the file.
%
%     call with options -> dolfyn_read(filename, userdata=false, nens=12) 
%
% Returns
% ---------
%     ds: structure 
%         Structure from the binary instrument data
%        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    arguments
        filename 
        options.userdata = true;
        options.nens = nan;
    end
    
    % check to see if the filename input is a string
    if ~ischar(filename)
        ME = MException('MATLAB:dolfyn_read','filename must be a string');
        throw(ME);
    end
    
    % check to see if the file exists
    if ~isfile(filename)
        ME = MException('MATLAB:dolfyn_read','file does not exist');
        throw(ME);
    end
    
    % check to make sure userdata is bool or string
    if ~isa(options.userdata, 'logical') && ~isa(options.userdata, 'string')
        ME = MException('MATLAB:dolfyn_read','userdata must be a logical or string');
        throw(ME);
    end
    
    % check to make sure nens is numeric or nan
    if ~all(isa(options.nens, 'numeric'))
        ME = MException('MATLAB:dolfyn_read','nens must be numeric or nan');
        throw(ME);
    end
    
    % check to make sure if nens is numeric that its length is equal to 1 or 2   
    if ~isnan(options.nens)
        if length(options.nens) < 1 || length(options.nens) > 2
            ME = MException('MATLAB:dolfyn_read','nens must be a single value or tuple');
            throw(ME);
        end        
    end

    % Loop over binary readers until we find one that works.
    fun_map = struct(  'nortek',{@read_nortek},...                       
                       'signature',{@read_signature},...
                       'rdi',{@read_rdi});

    readers = fieldnames(fun_map);
    for qq = 1:numel(readers)
        reader = readers{qq};
        try
            ds = feval(fun_map.(reader),...
                filename,userdata=options.userdata,nens=options.nens);
        catch
            continue
        end        
        break;
    end
    if isempty(ds)
        ME = MException('MATLAB:dolfyn_read',['Unable to find a' ...
            ' suitable reader for file %s\n.', filename]);
        throw(ME);
    end
end
