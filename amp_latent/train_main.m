% clear;
clc;
%% Build Java
system('make clean')
system('make')
addpath('../libsvm-3.21/matlab');

%% parameters
Beta=1;                                                                                                                             %%%%%%%%%% Beta
%For testing purpose only (small dataset)
%TEST_RELATIONS = 51;

%% read examples
disp('Train read start');
% filename = 'train-riedel-10p.1.data';
filename = 'v.small.data1';
fid = fopen(filename);
num_egs=fscanf(fid,'%d',1);
NO_OF_RELNS=fscanf(fid,'%d',1);
NO_OF_RELNS=NO_OF_RELNS+1;

TEST_RELATIONS = NO_OF_RELNS;
%%%%%%%%%%%%%%%    to store no of sentences in each example
no_sentences_per_example=zeros(1,num_egs);                           
max_feature=0;
count_of_sentences=0;
%%%%%%%%%%%%%%%%% gold_db_matrix x vs y
gold_db_matrix=zeros(num_egs,NO_OF_RELNS);                       
for n = 1:num_egs
    
    %Reading Relations for Entity Pairs
    no_of_relations_in_current_example=fscanf(fid, '%d',1);
    for r=1:no_of_relations_in_current_example
        relationid=fscanf(fid,'%d',1);
        gold_db_matrix(n,relationid+1)=1;
    end
    
    %Reading Features for Sentences
    no_of_sentences_in_current_example=fscanf(fid, '%d',1);
    no_sentences_per_example(1,n)=no_of_sentences_in_current_example;
    
    %Read Feature String
    str = fgetl(fid);
    for s=1:no_of_sentences_in_current_example
        count_of_sentences=count_of_sentences+1;
        str = fgetl(fid);
        [no_of_features remaining]=strtok(str);
        no_of_features= str2num(no_of_features);
        features_to_triggered=strread(remaining,'%s','delimiter',' ');
        for idx = 1:no_of_features-1
            [feature weight] = strtok(features_to_triggered(idx),':');
            weight = strrep(weight,':',' ');
            feature=str2double(strtrim(feature));
            weight=str2double(strtrim(weight));
            feature_vect(count_of_sentences,feature)=weight;
        end    
    end    
end
[x1, max_feature] = size(feature_vect)
fclose(fid);
disp('Train read done');
%% read Test examples

disp('Test read start');
filename_test = 'testSVM.pos_r.data1';
fid_test = fopen(filename_test);
num_egs_test=fscanf(fid_test,'%d',1);
NO_OF_RELNS_test=fscanf(fid_test,'%d',1);
NO_OF_RELNS_test=NO_OF_RELNS_test+1;

%%%%%%%%%%%%%%%    to store no of sentences in each example
no_sentences_per_example_test=zeros(1,num_egs_test);                           
% max_feature=56648;
count_of_sentences_test=0;
%%%%%%%%%%%%%%%%% gold_db_matrix x vs y
gold_db_matrix_test=zeros(num_egs_test,NO_OF_RELNS_test);                      
for n = 1:num_egs_test
    
    %Reading Relations for Entity Pairs
    no_of_relations_in_current_example_test=fscanf(fid_test, '%d',1);
    for r=1:no_of_relations_in_current_example_test
        relationid_test=fscanf(fid_test,'%d',1);
        gold_db_matrix_test(n,relationid_test+1)=1;
    end
    
    %Reading Features for Sentences
    no_of_sentences_in_current_example_test=fscanf(fid_test, '%d',1);
    no_sentences_per_example_test(1,n)=no_of_sentences_in_current_example_test;
    feature_vect_test = zeros(num_egs_test, max_feature);
    
    %Read Feature String
    str = fgetl(fid_test);
    for s=1:no_of_sentences_in_current_example_test
        count_of_sentences_test=count_of_sentences_test+1;
        str = fgetl(fid_test);
        [no_of_features remaining]=strtok(str);
        no_of_features= str2num(no_of_features);
        features_to_triggered=strread(remaining,'%s','delimiter',' ');
        for idx = 1:no_of_features-1
            [feature weight] = strtok(features_to_triggered(idx),':');
            weight = strrep(weight,':',' ');
            feature=str2double(strtrim(feature));
            weight=str2double(strtrim(weight));
            if(feature <= max_feature)
                feature_vect_test(count_of_sentences_test, feature)=weight;
            end
%             feature_vect_test(count_of_sentences_test,feature)=weight;
        end    
    end    
end

Theta_micro_test= nnz(gold_db_matrix_test==0)/nnz(gold_db_matrix_test==1);
disp('Test read done');
fclose(fid_test);
%End of Read Test Data

 %% Write W to file for infer latent var
    fid_latent = fopen('tmp1/inf_lat_var_all', 'wt'); % Open for writing
    fprintf(fid_latent,'%d\n',NO_OF_RELNS-1 );
    fprintf(fid_latent,'%d\n',max_feature+1 );
    dlmwrite('tmp1/inf_lat_var_all',zeros(NO_OF_RELNS, max_feature+1),'-append', 'delimiter', ' '); %after appending 
    fclose(fid_latent);
    %% epoch loop
% v_last=0.5;
v=0.5;
Theta_micro= nnz(gold_db_matrix==0)/nnz(gold_db_matrix==1)
w_1_cost=1;
w_0_cost=1;
for epoch=1:40  %%%%%%%%%%%% epoch length
    %% Infer Latent Vars
    %delete existing
    system('rm tmp1/inf_lat_var_all.result');
    
    %call java
    system('./infer_latent_cmd.sh');
    
    %reading java results
    fileID = fopen('tmp1/inf_lat_var_all.result','r');
    formatSpec = '%d';
    latent_labels = fscanf(fileID,formatSpec);
    [latent_size,x1]=size(latent_labels);
    
    
    %% Other Matrices (Hard Coded)
%     
%     NO_OF_RELNS = 51+1;
%     max_feature = 56648;
%     feature_vect = rand(latent_size, max_feature);
    
    % Weight vector initialize
    W = zeros(NO_OF_RELNS, max_feature);
    bias = zeros(NO_OF_RELNS, 1);
    
    
    
    %% SVM Training
    predicted_matrix = zeros(NO_OF_RELNS,count_of_sentences);
    for i=1:TEST_RELATIONS                                                                                                                                             %%%%%%%%% relations
        temp_reln_labels = zeros(latent_size,1);
        temp_reln_labels(latent_labels==i) = 1;
        
        %Handling the situation when no +ve examples are there
        if(sum(temp_reln_labels) == 0)  
            continue;   
        end
        
        model = svmtrain(temp_reln_labels, feature_vect, strcat('-s 0 -t 2 -c 1 -g 0.1 -w1 ', num2str(w_1_cost),' -w0 ',num2str(w_0_cost)));
        
        % Need to verify next 2 lines  (taken from http://stackoverflow.com/questions/10131385/matlab-libsvm-how-to-find-the-w-coefficients)
        W(i+1,:) = (model.sv_coef' * full(model.SVs));
        bias(i+1,:)=-model.rho;
        predicted_matrix(i+1,:)=sign(W(i+1,:) * feature_vect' +bias(i+1));
        
    end
    
    %% SVM Prediction - Training
    
    %Replicate bias to add with W
    bias_repl=repmat(bias,1,latent_size);
    
    %Prediction vector (need to be more verbose with comments)
    [predictions_score,predictions_vect] = max(W * feature_vect' + bias_repl);
    predictions_vect = predictions_vect-1;
    

    %% to claculate next v - hence need to calculate TP-TN relation wise by comparing gold_db_matrix with predicted one(which is sentence wise so need to do aggregate inference)
    sentence_index=0;
    predicted_db_matrix=zeros(num_egs,NO_OF_RELNS);
%     [~, b]=size(no_sentences_per_example);
    for len=1:num_egs
        for s=1:no_sentences_per_example(1,len)
           sentence_index=sentence_index+1;
%            for iid=1:TEST_RELATIONS                                                                                                                                 %%%%%%%%% relations
%                if predicted_matrix(iid,sentence_index)==1
%                     predicted_db_matrix(len,iid)=1; 
%                end 
%            end    
           if(predictions_vect(sentence_index) ~= 0)
                predicted_db_matrix(len,predictions_vect(sentence_index)+1)=1; 
           end

        end    
    
    end
    
    %TP 
    
    
    [a b]=size(gold_db_matrix);
    
    %Find cumulative TP
    TP_micro=sum(sum(gold_db_matrix.*predicted_db_matrix))/(a*b)
    
    %Find cumulative TN
    c=zeros(a,b);
    d=zeros(a,b);
    c(gold_db_matrix==0) = 1;
    d(predicted_db_matrix==0) = 1;
    TN_micro=sum(sum(c.*d))/(a*b)

   
    
    v=((1+Beta^2)*TP_micro)/(Beta^2+Theta_micro+TP_micro-Theta_micro*TN_micro)
    w_1_cost=1+Beta^2-v
    w_0_cost=v*Theta_micro
    
    disp('Epoch Done!!!');
    %% Calculate TP & TN - Example
    
    % a=[1 0 0 1 0 1 1]
    % b=[1 0 0 0 0 1 0]
    % TP = sum(a.*b)
    %
    % c = zeros(1,7)
    % d = zeros(1,7)
    % c(a==0) = 1
    % d(b==0) = 1
    % TN = sum(c.*d)
    
    
     %% SVM Prediction - Test
    
    %Replicate bias to add with W
    bias_repl_test=repmat(bias,1,count_of_sentences_test);
    
    %Prediction vector (need to be more verbose with comments)
    [predictions_score_test,predictions_vect_test] = max(W * feature_vect_test' + bias_repl_test);
    predictions_vect_test = predictions_vect_test-1;
    
    
    %% Write W to file for infer latent var
    
    fid_latent = fopen('tmp1/inf_lat_var_all', 'wt'); % Open for writing
    fprintf(fid_latent,'%d\n',NO_OF_RELNS-1 );
    fprintf(fid_latent,'%d\n',max_feature+1 );
    dlmwrite('tmp1/inf_lat_var_all',[W bias],'-append', 'delimiter', ' '); %after appending                                  
    fclose(fid_latent);
    
    %% to claculate next v - hence need to calculate TP-TN relation wise by comparing gold_db_matrix with predicted one(which is sentence wise so need to do aggregate inference)
    sentence_index_test=0;
    predicted_db_matrix_test=zeros(num_egs_test,NO_OF_RELNS_test);
%     [~, b]=size(no_sentences_per_example);
    for len=1:num_egs_test
        for s=1:no_sentences_per_example_test(1,len)
           sentence_index_test=sentence_index_test+1;
           if(predictions_vect_test(sentence_index_test) ~= 0)
                predicted_db_matrix_test(len,predictions_vect_test(sentence_index_test)+1)=1; 
           end

        end    
    
    end
    
    %TP 
    
    
    [a b]=size(gold_db_matrix_test);
    
    %Find cumulative TP
    TP_micro_test=sum(sum(gold_db_matrix_test.*predicted_db_matrix_test))/(a*b);
    
    %Find cumulative TN
    c=zeros(a,b);
    d=zeros(a,b);
    c(gold_db_matrix_test==0) = 1;
    d(predicted_db_matrix_test==0) = 1;
    TN_micro_test=sum(sum(c.*d))/(a*b);

   
    
    v_test=((1+Beta^2)*TP_micro_test)/(Beta^2+Theta_micro_test+TP_micro_test-Theta_micro_test*TN_micro_test)
    
    
    fileID = fopen('fscore.dat','a');
    nbytes = fprintf(fileID,'%f\n',v_test);
    fclose(fileID);
    
    
    
     system('./evaluate_naacle.sh');
     
end






























