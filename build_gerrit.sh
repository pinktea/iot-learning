#!/bin/bash

# This script is created by MEG R&D I&T 
# Before you use it, pls first read through
# You can contact yunyi.yin@marelli.com to get details if needed.
# You MUST know one thing: This script is for the original Google Android .repo/manifest.xml. 
# If you changed manifest.xml, the script will change accordingly.



set +e

#Options to set project-related attributes
GERRIT_PROJECT_PREFIX="meg-8155-cockpit/lagvm"
GERRIT_PARENT_ACCESS_INHERIT="meg-8155-cockpit-base"
USER_NAME="admin"
SERVER_IP="10.129.125.32"
SERVER_PORT="29418"

#Make sure you are entering top-level directory
LOCAL_PATH=`pwd`
MANIFEST_XML_FILE=$LOCAL_PATH/.repo/manifest.xml
#MANIFEST_XML_FILE=$LOCAL_PATH/manifest.xml
GERRIT_GIT_REPOS=$LOCAL_PATH/gerrit_git_repos
GERRIT_GIT_PATHS=$LOCAL_PATH/gerrit_git_paths


TOTAL_GITS=0

# This function is to parse Manifest.xml file to see
function parseManifest()
{
	#Create Zero-Bytes NULL file(Not use "echo >", it will create at least one-byte file)
	:> $GERRIT_GIT_REPOS
	:> $GERRIT_GIT_PATHS
    while read LINE
    do
        command_line=`echo $LINE | grep "<project"`
        if [ "$command_line" ]
        then
            #echo $LINE
            git_repo_line=${LINE#*name=\"}
            git_path_line=${LINE#*path=\"}
            if [ "$git_repo_line" ] && [ "$git_path_line" ]
            then
                reposity_name=${git_repo_line%%\"*}
                reposity_path=${git_path_line%%\"*}
                echo "$reposity_name" >> $GERRIT_GIT_REPOS
                echo "$reposity_path" >> $GERRIT_GIT_PATHS
            fi
        fi
	done < $MANIFEST_XML_FILE
	
	TOTAL_GITS=`cat $GERRIT_GIT_REPOS|wc -l`
	echo "****** The Gits in total are $TOTAL_GITS ******"
}

#Create repo on Gerrit
function createGerritRepos()
{
    for i in `cat $GERRIT_GIT_REPOS`;
    do
        echo $i
        echo "ssh -p $SERVER_PORT $USER_NAME@$SERVER_IP gerrit create-project --empty-commit $GERRIT_PROJECT_PREFIX/$i"
		# ssh -p 29418 admin@10.129.125.32 gerrit ls-project
        #create empty project on Gerrit
        ssh -p $SERVER_PORT $USER_NAME@$SERVER_IP gerrit create-project --empty-commit $GERRIT_PROJECT_PREFIX/$i
		#grant Access Rights
		ssh -p $SERVER_PORT $USER_NAME@$SERVER_IP gerrit set-project-parent --parent $GERRIT_PARENT_ACCESS_INHERIT $GERRIT_PROJECT_PREFIX/$i
    done
}


#Push Local Repo to Gerrit Server
function pushLocalToGerrit()
{
	i=0
	j=0
	while read LINE
	do
		# Every time you make sure you are doing right thing to enter top-level directory
		cd $LOCAL_PATH
        command_line=`echo $LINE | grep "<project"`
        if [ "$command_line" ]
		then
			git_repo_line=${LINE#*name=\"}
			git_path_line=${LINE#*path=\"}
			git_upstream_line=${LINE#*upstream=\"}
			if [ "$git_repo_line" ] && [ "$git_path_line" ]
			then
				repo_name=${git_repo_line%%\"*}
				repo_path=${git_path_line%%\"*}
				#you may use git branch -u $repo_upstream newBranch
				repo_upstream=${git_upstream_line%%\"*}
				echo "repo_name $repo_name" "; repo_path $repo_path"
				if [ -d "$LOCAL_PATH/$repo_path" ]
				then
					# Enter current path to find .git hidden folder, where you can use one series of "git" commands
					cd $LOCAL_PATH/$repo_path

					# Print current path to make sure you are entering what you expected
					echo `pwd`
					#git remote add origin ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name
					
					# The following commands will push all branches to gerrit one by one
					# It is better to make sure every branch is pushed to Gerrit
					remote_repo=`git remote`
					local_branches=`git branch -a | grep "remotes/$remote_repo"`
					for branch in `echo $local_branches`
					do
						branch_name=${branch#*$remote_repo\/}
						echo "Local Branch is ****** $branch_name ****** ===> $i/$TOTAL_GITS"
						#Push Branch
						git push -o skip-validation ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name $branch:refs/heads/$branch_name
					done
					
					# The following commands will push all tags to gerrit one by one. 
					# If you are using git push --tags origin, you will come into trouble such as "Internal Server Error"
					tags_branch=`git tag`
					for tag_branch in `echo $tags_branch`
					do
						echo "Tag is ****** $tag_branch ******,===> $i/$TOTAL_GITS"
						#Push Tag 
						git push -o skip-validation --force ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name $tag_branch:refs/tags/$tag_branch
					done
				elif [ -d "$LOCAL_PATH/$repo_name" ]
				then
					# Enter current path to find .git hidden folder, where you can use one series of "git" commands
					cd $LOCAL_PATH/$repo_name
					# Print current path to make sure you are entering what you expected
					echo `pwd`
					#git remote add origin ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name
					
					# The following commands will push all branches to gerrit one by one
					# It is better to make sure every branch is pushed to Gerrit
					remote_repo=`git remote`
					local_branches=`git branch -a | grep "remotes/$remote_repo"`
					for branch in `echo $local_branches`
					do
						branch_name=${branch#*$remote_repo\/}
						echo "Local Branch is ****** $branch_name ****** ===> $i/$TOTAL_GITS"
						#Push Branch
						git push -o skip-validation ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name $branch:refs/heads/$branch_name
					done
					
					# The following commands will push all tags to gerrit one by one. 
					# If you are using git push --tags origin, you will come into trouble such as "Internal Server Error"
					tags_branch=`git tag`
					for tag_branch in `echo $tags_branch`
					do
						echo "Tag is ****** $tag_branch ******,===> $i/$TOTAL_GITS"
						#Push Tag 
						git push -o skip-validation --force ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name $tag_branch:refs/tags/$tag_branch
					done
				else
					j=$[$j+1]
					echo "Warning: $repo_path  does NOT exist......[$j/$TOTAL_GITS]"
				fi
			fi
			i=$[$i+1]
		fi
	done < $MANIFEST_XML_FILE
}
			

#Force every git to one master branch
function switchLocalToMasterBranch()
{

    while read LINE
    do
        cd $LOCAL_PATH
        command_line=`echo $LINE | grep "<project"`
        if [ "$command_line" ]
        then
            #echo $LINE
            git_repo_line=${LINE#*name=\"}
            git_path_line=${LINE#*path=\"}

            if [ "$git_repo_line" ] && [ "$git_path_line" ]
            then
                reposity_name=${git_repo_line%%\"*}
                reposity_path=${git_path_line%%\"*}
				if [ -d "$LOCAL_PATH/$repo_path" ]
				then
					cd $LOCAL_PATH/$reposity_path
					echo `pwd`
					git branch master
					git checkout master
				fi
			fi
        fi
	done < $MANIFEST_XML_FILE
}




#Push Local Repo to Gerrit Server
function push_lagvm_ToGerrit()
{

	#git push -o skip-validation ssh://admin@10.129.125.32:29418/meg-8155-cockpit/snapdragon-auto-gen3-hqx-spf-0-1_hlos_dev_la-q master:refs/heads/master
					
	# The following commands will push all tags to gerrit one by one. 
	# If you are using git push --tags origin, you will come into trouble such as "Internal Server Error"
	tags_branch=`git tag`
	for tag_branch in `echo $tags_branch`
	do
		echo "Tag is ****** $tag_branch ******"
		#Push Tag 
		git push -o skip-validation --force ssh://admin@10.129.125.32:29418/meg-8155-cockpit/snapdragon-auto-gen3-hqx-spf-0-1_hlos_dev_la-q $tag_branch:refs/tags/$tag_branch
	done

}




function push_qnx_ToGerrit()
{

	git push -o skip-validation ssh://admin@10.129.125.32:29418/meg-8155-cockpit/snapdragon-auto-gen3-hqx-spf-0-1_hlos_dev_qnx master:refs/heads/master
					
	# The following commands will push all tags to gerrit one by one. 
	# If you are using git push --tags origin, you will come into trouble such as "Internal Server Error"
	tags_branch=`git tag`
	for tag_branch in `echo $tags_branch`
	do
		echo "Tag is ****** $tag_branch ******"
		#Push Tag 
		git push -o skip-validation --force ssh://admin@10.129.125.32:29418/meg-8155-cockpit/snapdragon-auto-gen3-hqx-spf-0-1_hlos_dev_qnx $tag_branch:refs/tags/$tag_branch
	done

}


function push_boot_ToGerrit()
{

	git push -o skip-validation ssh://admin@10.129.125.32:29418/meg-8155-cockpit/snapdragon-auto-gen3-hqx-spf-0-1_hlos_dev_boot master:refs/heads/master
					
	# The following commands will push all tags to gerrit one by one. 
	# If you are using git push --tags origin, you will come into trouble such as "Internal Server Error"
	tags_branch=`git tag`
	for tag_branch in `echo $tags_branch`
	do
		echo "Tag is ****** $tag_branch ******"
		#Push Tag 
		git push -o skip-validation --force ssh://admin@10.129.125.32:29418/meg-8155-cockpit/snapdragon-auto-gen3-hqx-spf-0-1_hlos_dev_boot $tag_branch:refs/tags/$tag_branch
	done

}

#This function is to see which branch current directory is located in
#Sometimes as you type "git branch",you will see "* (no branch)" on the console
#Right now ,you need to use this command to determine which branch is correct to switch
function checkBranch()
{
	#local folder=`pwd`
	#local folder="$(pwd)"
	#echo $folder
	#[ -n "$1" ] && folder="$1"
	echo $1
	current_branch=`git -C "$1" rev-parse --abbrev-ref HEAD | grep -v HEAD || \
	git -C "$1" describe --tags HEAD || \
	git -C "$1" rev-parse HEAD`
	
	#git rev-parse --abbrev-ref HEAD | grep -v HEAD || git describe --tags HEAD || git rev-parse HEAD

	echo "current branch is $current_branch"
	return current_branch

}
#Create branch according to tag
# 1. git origin fetch 
# 2. git branch newBranch tag-name
# 3. git checkout newBranch
# 4. git push origin newBranch 
function changeBranch()
{
	#local folder=`pwd`
	#local folder="$(pwd)"
	#echo $folder
	#[ -n "$1" ] && folder="$1"
	echo $1
	current_branch=`git -C "$1" rev-parse --abbrev-ref HEAD | grep -v HEAD || \
	git -C "$1" describe --tags HEAD || \
	git -C "$1" rev-parse HEAD`
	echo "current branch is $current_branch"
	git branch master $current_branch
	let flag=$?
	if [[ $flag = 0 ]]
	then
		echo "master"
	else
		echo "not master"
	fi
	git checkout master


}


#Make Gerrit's git to the same branch
function switchToTheSameBranch()
{
	i=0
	j=0
	while read LINE
	do
		# Every time you make sure you are doing right thing to enter top-level directory
		cd $LOCAL_PATH
        command_line=`echo $LINE | grep "<project"`
        if [ "$command_line" ]
		then
			git_repo_line=${LINE#*name=\"}
			git_path_line=${LINE#*path=\"}
			if [ "$git_repo_line" ] && [ "$git_path_line" ]
			then
				repo_name=${git_repo_line%%\"*}
				repo_path=${git_path_line%%\"*}
				echo "repo_name $repo_name" "; repo_path $repo_path"
				if [ -d "$LOCAL_PATH/$repo_path" ]
				then
					# Enter current path to find .git hidden folder, where you can use one series of "git" commands
					cd $LOCAL_PATH/$repo_path
					i=$[$i+1]
					# Print current path to make sure you are entering what you expected
					currentPwd=`pwd`
					changeBranch "$currentPwd"
					echo "****** [$i/$TOTAL_GITS] ******"
					#As you switch to new Branch,pls open thi line 
					#git push -o skip-validation ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name master:refs/heads/master
				elif [ -d "$LOCAL_PATH/$repo_name" ]
				then
					# Enter current path to find .git hidden folder, where you can use one series of "git" commands
					cd $LOCAL_PATH/$repo_name
					i=$[$i+1]
					# Print current path to make sure you are entering what you expected
					currentPwd=`pwd`
					changeBranch "$currentPwd"
					echo "****** [$i/$TOTAL_GITS] ******"
					#As you switch to new Branch,pls open thi line 
					#git push -o skip-validation ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name master:refs/heads/master
					
				else
					j=$[$j+1]
					echo "Warning: $repo_path  does NOT exist......[$j/$TOTAL_GITS]"
				fi
			fi
		fi
	done < $MANIFEST_XML_FILE
}

#		
#270457.pts-19.MMGZ-W1910-174]


#Push Local Repo to Gerrit Server
function pushLocal2ToGerrit()
{
	i=0
	j=0
	while read LINE
	do
		# Every time you make sure you are doing right thing to enter top-level directory
		cd $LOCAL_PATH
        command_line=`echo $LINE | grep "<project"`
        if [ "$command_line" ]
		then
			git_repo_line=${LINE#*name=\"}
			git_path_line=${LINE#*path=\"}
			git_upstream_line=${LINE#*upstream=\"}
			if [ "$git_repo_line" ] && [ "$git_path_line" ]
			then
				repo_name=${git_repo_line%%\"*}
				repo_path=${git_path_line%%\"*}
				#you may use git branch -u $repo_upstream newBranch
				repo_upstream=${git_upstream_line%%\"*}
				echo "repo_name $repo_name" "; repo_path $repo_path"
				if [ -d "$LOCAL_PATH/$repo_name" ]
				then
					# Enter current path to find .git hidden folder, where you can use one series of "git" commands
					cd $LOCAL_PATH/$repo_name

					# Print current path to make sure you are entering what you expected
					echo `pwd`
					echo "$i/$TOTAL_GITS $repo_name"
					#git remote add origin ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name
					
					# The following commands will push all branches to gerrit one by one
					# It is better to make sure every branch is pushed to Gerrit
					remote_repo=`git remote`
					local_branches=`git branch -a | grep "remotes/$remote_repo"`
					for branch in `echo $local_branches`
					do
						branch_name=${branch#*$remote_repo\/}
						echo "Local Branch is ****** $branch_name ****** ===> $i/$TOTAL_GITS"
						#Push Branch
						git push -o skip-validation ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name $branch:refs/heads/$branch_name
					done
					
					# The following commands will push all tags to gerrit one by one. 
					# If you are using git push --tags origin, you will come into trouble such as "Internal Server Error"
					tags_branch=`git tag`
					for tag_branch in `echo $tags_branch`
					do
						echo "Tag is ****** $tag_branch ******,===> $i/$TOTAL_GITS"
						#Push Tag 
						git push -o skip-validation --force ssh://$USER_NAME@$SERVER_IP:$SERVER_PORT/$GERRIT_PROJECT_PREFIX/$repo_name $tag_branch:refs/tags/$tag_branch
					done
					i=$[$i+1]
				else
					j=$[$j+1]
					echo "Warning: $repo_path  does NOT exist......[$j/$TOTAL_GITS]"
				fi
			fi
		fi
	done < $MANIFEST_XML_FILE
}

			
parseManifest
#createGerritRepos
#pushLocalToGerrit
pushLocal2ToGerrit
#checkBranch
#push_lagvm_ToGerrit
#push_qnx_ToGerrit
#push_boot_ToGerrit
#switchToTheSameBranch
set -e