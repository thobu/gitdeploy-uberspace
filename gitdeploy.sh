#!/bin/sh
############################
# Uberspace Gitdeploy V0.2.2 ###
##################################
#                               #####
#       2013-08-03              ##########
#       ThoBu                   ################
#       thobu@schickzu.de       #######################
#                               ###################################
############################################################################
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    Dieses Programm ist Freie Software: Sie können es unter den Bedingungen
#    der GNU General Public License, wie von der Free Software Foundation,
#    Version 3 der Lizenz oder (nach Ihrer Wahl) jeder neueren
#    veröffentlichten Version, weiterverbreiten und/oder modifizieren.
#
#    Dieses Programm wird in der Hoffnung, dass es nützlich sein wird, aber
#    OHNE JEDE GEWÄHRLEISTUNG, bereitgestellt; sogar ohne die implizite
#    Gewährleistung der MARKTFÄHIGKEIT oder EIGNUNG FÜR EINEN BESTIMMTEN ZWECK.
#    Siehe die GNU General Public License für weitere Details.
#
#    Sie sollten eine Kopie der GNU General Public License zusammen mit diesem
#    Programm erhalten haben. Wenn nicht, siehe <http://www.gnu.org/licenses/>.
#
################################################################################
#
#       Uberspace Helper-Script to deploy (local, web ,node) git repository
#
################################################################################


#settings
user=uberspace-user #your uberspace user
domain=deploy-domain #your deploy domain for web and node

#default uberspace settings
startport=61000 #61000 Startport uberspace
endport=65535 #65535


#Start Script
if [ -z "$#" ]; then
echo please define repo name
exit 0
fi

option=$1
repo=$2

newGitRepo(){

        mkdir /home/$user/repositories/$repo.git
        cd /home/$user/repositories/$repo.git
        git init --bare
}
addGitFiles(){
        git --work-tree=/home/$user/node/$repo.$domain/ --git-dir=/home/$user/repositories/$repo.git/ add .
        git --work-tree=/home/$user/node/$repo.$domain/ --git-dir=/home/$user/repositories/$repo.git/ commit -m "First commit" >/dev/null
}
newWebPostHook(){
        mkdir /var/www/virtual/$user/$repo.$domain/
        cd /home/$user/repositories/$repo.git/hooks/
        echo #!/bin/sh >> post-receive
        echo unset GIT_INDEX_FILE >> post-receive
        echo export GIT_WORK_TREE=/var/www/virtual/$user/$repo.$domain/ >> post-receive
        echo export GIT_DIR=/home/$user/repositories/$repo.git/ >> post-receive
        echo git checkout -f >> post-receive
        echo echo post-receive-hook fired! >> post-receive
        chmod +x post-receive

}
newNodePostHook(){
        mkdir /var/www/virtual/$user/$repo.$domain/

        cd /home/$user/repositories/$repo.git/hooks/
        echo #!/bin/sh >> post-receive
        echo unset GIT_INDEX_FILE >> post-receive
         echo export GIT_WORK_TREE=/home/$user/node/$repo.$domain/ >> post-receive
                echo export GIT_DIR=/home/$user/repositories/$repo.git/ >> post-receive
                echo git checkout -f >> post-receive
                echo svc -du /home/$user/service/$repo >> post-receive
                echo echo post-receive-hook fired! >> post-receive
                chmod +x post-receive

        }


        endInfo(){
                echo "Clone URL: ssh://$user@<server>.uberspace.de/home/$user/repositories/$repo.git/"
                echo "Web URL: http://$repo.$domain"
                echo "Start Service svc -u /home/$user/service/$repo"
                echo "Stop Service svc -d /home/$user/service/$repo"
                echo "Restart Service svc -du /home/$user/service/$repo"
        }
        addNodeService(){
                freePortSearch
                cd "/var/www/virtual/$user/$repo.$domain/"
                echo RewriteEngine On >> .htaccess
                echo 'RewriteRule ^(.*)$ http://localhost:$freeport/$1 [P]'  >> .htaccess
                nodeScript
        }

        freePortSearch(){
                shuf=`shuf -i $startport-$endport`
                for i in $shuf
                do
                        netstat -tulpen 2>/dev/null | grep ":$i .* LISTEN" >/dev/null
                        if [ $? -eq 1 ]
                        then
                                freeport=$i
                                break
                        fi
                done
        }
        freePortInfo(){
                echo "Free TCP/UDP Port on this machine is $freeport"
        }
        nodeScript(){
                mkdir /home/$user/node/$repo.$domain/
                cd /home/$user/node/$repo.$domain/
                echo "var http = require('http');" >> app.js
                echo "var server = http.createServer(function (req, res) {" >> app.js
                echo "  res.writeHead(200, {'Content-Type': 'text/plain'});" >> app.js
 echo "  res.end('Hello World\n');" >> app.js
        echo "});" >> app.js
        echo "server.listen($freeport);" >> app.js
        uberspace-setup-service $repo node /home/$user/node/$repo.$domain/app.js 1>/dev/null
        svc -u /home/$user/service/$repo
}
remove(){
        cd /home/$user/service/$repo
        svc -dx . log
        rm /home/$user/service/$repo
        rm -rf /home/$user/etc/run-$repo
        rm -rf /var/www/virtual/$user/$repo.$domain/
        rm -rf /home/$user/node/$repo.$domain/
        rm -rf /home/$user/repositories/$repo.git/
}
errorParameter(){
        echo "./gitdeploy [option] [repository]"
        echo "Options:"
        echo "local - Git Repository without Webdirectory"
        echo "web - Git Repository with Webdirectory"
        echo "node - Git Repository with Webdirectory and Uberspace Service"
        echo "freeport - search a free TCP/UDP Port on localhost"
        echo "remove - Delete all Files (Webdirectory,Git,Service)"
}
case $option in
        local)
                newGitRepo
                endInfo
        ;;
        node)
                newGitRepo
                newNodePostHook
                addNodeService
                addGitFiles
                endInfo
        ;;
        web)
                newGitRepo
                newWebPostHook
                endInfo
        ;;
        freeport)
                freePortSearch
                freePortInfo
        ;;
 remove)
                remove;;
        *)
                errorParameter;;
esac
