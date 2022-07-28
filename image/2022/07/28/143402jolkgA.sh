#!/bin/bash
# 检查是否为root用户，脚本必须在root权限下运行
if [[ "$(whoami)" != "root" ]]; then
    echo "please run this script as root !" >&2
    # exit 1
fi
#echo -e "\033[31m the script only Support CentOS_7 x86_64 \033[0m"
#echo -e "\033[31m system initialization script, Please Seriously. press ctrl+C to cancel \033[0m"

# 检查是否为64位系统，这个脚本只支持64位脚本
platform=`uname -i`
if [ $platform != "x86_64" ];then
    echo "this script is only for 64bit Operating System !"
    # exit 1
fi


reserve=0
version=1
name=2
port=3
path=4
ready=5
project=6
origin=7


######################## 内部方法 ########################
# 得到配置内容
getConf() {
    global=0

    # 0 global config, 1 normal config
    configType=0

    # (reserve version name port path needReady project origin @)
    array_config=()
    array_config_item=(-1 -1 'global' 0 -1 false -1 -1 @)

    confPath=$(dirname $(readlink -f $0))/service.conf

    if [[ -n $dDCConfPath ]]; then
        confPath=$dDCConfPath
    fi

    while read line
    do
        if [[ -n $line ]]; then

            case $line in
                (\[*-*|\])
                    # echo 'mes|pbs'
                    originName=`getServiceItemOriginPrefix $line`
                    if [ $configType == 0 ]; then
                        # global config
                        global_config_item[$origin]=$originName
                        array_config[${#array_config[*]}]=${global_config_item[*]}
                    else
                        # normal config
                        array_config[${#array_config[*]}]=${array_config_item[*]}
                    fi

                    array_config_item=(${global_config_item[*]})
                    configType=1

                    array_config_item[$origin]=$originName
                    ;;
                (\[global\])
                    # echo 'global'
                    configType=0
                    global_config_item=(${array_config_item[*]})
                    global_config_item[$name]='global'
                    ;;
                ([^#]*\=*)
                    # echo 'para'
                    line=${line//\ /}
                    para=($(split $line "="))
                    if [ $configType == 0 ]; then
                        # global config
                        global_config_item[${para[0]}]=${para[1]}
                    else
                        # normal config
                        array_config_item[${para[0]}]=${para[1]}
                    fi
            esac

       fi
    done < $confPath

    array_config[${#array_config[*]}]=${array_config_item[*]}

    # viewArr ${array_config[*]}
    echo ${array_config[*]}
}

# 修改配置内容(未启用)
setConf() {
    echo "setConf"
}

# 分割字符串
split() {
    # echo "$1"
    OLD_IFS="$IFS"
    IFS=$2
    arr=($1)
    IFS="$OLD_IFS"
    echo ${arr[*]}
}

# 看数组(调试用)
viewArr() {
    arr=$@
    arr=${arr//\ @\ /@}
    arr=${arr//\ /+}

    OLD_IFS="$IFS"
    IFS="@"
    viewArrtemp_arr=($arr)
    IFS="$OLD_IFS"

    for ((viewArri=0; viewArri<${#viewArrtemp_arr[*]}; viewArri++))
    do
        viewArrtemp=${viewArrtemp_arr[$viewArri]}
        echo ${viewArrtemp//\+/\ }
    done
}

# 得到service.conf中每一项标题的名字前缀
getServiceItemOriginPrefix() {
    SIOPrefix=$@
    SIOPrefix=${SIOPrefix#[}
    SIOPrefix=${SIOPrefix%]}
    SIOPrefix=${SIOPrefix%%-*}
    echo $SIOPrefix
}

# 得到docker run命令
getDockerRunCommand() {
    # echo 'getDockerRunCommand'
    gdc_item=($@)
    if [[ ${gdc_item[$path]} != '-1' ]]; then
        gdc_tempPath=${gdc_item[$path]}
        gdc_temp=${gdc_tempPath//,/\ }
        dockerPath=($gdc_temp)
        for ((gdc_i=0; gdc_i<${#dockerPath[*]}; gdc_i++))
        do
            dockerPath[$gdc_i]=" -v ${dockerPath[$gdc_i]}"
        done

        dockerPrivileged=" --privileged=true"

    fi
    if [[ -n ${gdc_item[$name]} ]]; then
        dockerName=${gdc_item[$name]}
    fi
    dockerPort=' --network=host'
    if [[ -n ${gdc_item[$port]} ]]; then
        dportList=($(split ${gdc_item[$port]}  ","))
        dInPort=${dportList[0]}
        dOutPort=${dportList[1]}
        if [[ -n $dOutPort ]]; then
            dockerPort='-p '$dOutPort':'$dInPort
        fi
    fi
    if [[ -n ${gdc_item[$version]} ]]; then
        dockerVersion=${gdc_item[$version]}
    fi
    if [[ ${gdc_item[$project]} != '-1' ]]; then
        dockerProject=${gdc_item[$project]}-
    fi
    if [[ -n ${gdc_item[$origin]} ]]; then
        dockerOrigin=${gdc_item[$origin]}
    fi
    echo "docker run $dockerPrivileged -d $dockerPort ${dockerPath[*]}  --name $dockerProject$dockerName tofflons-docker.pkg.coding.net/${dockerOrigin}/docker/$dockerName:$dockerVersion"
}

# 得到docker restart命令
getDockerRestartCommand() {
    # echo 'getDockerRestartCommand'
    gdc_item=($@)
    if [[ -n ${gdc_item[$name]} ]]; then
        dockerName=${gdc_item[$name]}
    fi
    echo "docker restart $dockerName"
}

# 得到docker start命令
getDockerStartCommand() {
    # echo 'getDockerStartCommand'
    gdc_item=($@)
    if [[ -n ${gdc_item[$name]} ]]; then
        dockerName=${gdc_item[$name]}
    fi
    echo "docker start $dockerName"
}

# 计算时间
calcTime() {
    second=$1
    day=$[$second / 86400]
    second=$[$second % 86400]

    hour=$[$second / 3600]
    second=$[$second % 3600]

    minute=$[$second / 60]
    second=$[$second % 60]

    if [ $day -gt 0 ]; then
        infoDay="$day days,"
    fi
    if [ $hour -gt 0 ]; then
        infoHour="$hour hours,"
    fi
    if [ $minute -gt 0 ]; then
        infoMinute="$minute minutes,"
    fi
    infoSecond="$second seconds."

    echo $infoDay $infoHour $infoMinute $infoSecond
}

# 监听端口
listenPort() {
    sleepTime=2
    limitMinites=5
    maxLoop=$[$limitMinites * 60 / $sleepTime]
    loopCount=$maxLoop
    lport="0"

    while (($maxLoop && !$lport))
    do
        lport=`netstat -nlt|grep $1|wc -l`
        loopCount=$[$loopCount - 1]
        sleep $sleepTime
    done

    echo $lport $[($maxLoop - $loopCount) * $sleepTime]
}

# 检查所有服务是否都已启动
checkRunning() {
    sleepTime=2
    limitMinites=5
    maxLoop=$[$limitMinites * 60 / $sleepTime]
    loopCount=$maxLoop
    checkPorts=($1)
    check_run_ports=($1)

    while ((${#check_falied_ports[*]} && $loopCount))
    do
        check_falied_ports=()
        for ((cRuni=0; cRuni<${#check_run_ports[*]}; cRuni++))
        do
            check_run_temp_port=${check_run_ports[$cRuni]};
            check_run_port_count=`netstat -nlt|grep $check_run_temp_port|wc -l`
            if [ check_run_port_count -eq 0 ]; then
                check_falied_ports[${#check_falied_ports[*]}]=$check_run_temp_port;
            fi
        done

        if [${#check_falied_ports[*]} -ne 0]; then
            check_run_ports=(${check_falied_ports[*]})
            loopCount=$[$loopCount - 1]
            sleep $sleepTime
        fi

    done

    if [ $loopCount -eq 0 ]; then
        echo ${check_falied_ports[*]}
    fi
}

# 执行函数
doCommand() {
    outFor=0
    for ((cmd_i=0; cmd_i<${#list[*]}; cmd_i++))
    do
        if [[ $command == ${list[$cmd_i]} && $outFor!=1 ]]; then
            eval ${list[$cmd_i]} $mainPara
            outFor=1
        fi
    done
}

# 根据容器名得到单个服务的配置
runOneContainerByName() {
    gOCBN_name=$1
    gOCBN_conf=`getConf`

    # 解析二维数组
    gOCBN_conf=${gOCBN_conf//\ @\ /@}
    gOCBN_conf=${gOCBN_conf//\ /+}

    OLD_IFS="$IFS"
    IFS="@"
    gOCBN_config_arr=($gOCBN_conf)
    IFS="$OLD_IFS"
    # 解析二维数组

    for ((gOCBN_i=1; gOCBN_i<${#gOCBN_config_arr[*]}; gOCBN_i++))
    do
        gOCBN_temp=${gOCBN_config_arr[$gOCBN_i]}
        gOCBN_temp=${gOCBN_temp//\+/\ }
        gOCBN_item=($gOCBN_temp)

        if [[ ${gOCBN_item[$name]} == $gOCBN_name ]]; then
            gOCBN_dockerCommand=`getDockerRunCommand $gOCBN_temp`
            echo $gOCBN_dockerCommand
            eval $gOCBN_dockerCommand
        fi
    done

}

# 创建容器
doDockerContainer() {
    dockerCommandType=$1
    dDCConfPath=$2
    echo "doDockerContainer $dockerCommandType"

    start_time=$(date +%s)
    configList=`getConf $dDCConfPath`

    # 解析二维数组
    configList=${configList//\ @\ /@}
    configList=${configList//\ /+}

    OLD_IFS="$IFS"
    IFS="@"
    config_arr=($configList)
    sdc_success_arr=()
    sdc_failed_arr=()
    sdc_port_arr=()
    sdc_spend_time=0
    IFS="$OLD_IFS"
    # 解析二维数组

    for ((sdc_i=1; sdc_i<${#config_arr[*]}; sdc_i++))
    do
        sdc_temp=${config_arr[$sdc_i]}
        sdc_temp=${sdc_temp//\+/\ }
        sdc_item=($sdc_temp)

        case $dockerCommandType in
            (run)
                dockerCommand=`getDockerRunCommand $sdc_temp`
                ;;
            (start)
                dockerCommand=`getDockerStartCommand $sdc_temp`
                ;;
            (restart)
                dockerCommand=`getDockerRestartCommand $sdc_temp`
                ;;
            (*)
                ;;
        esac

        echo $dockerCommand
        eval $dockerCommand

        dport=${sdc_item[$port]}
        sdc_port_arr[${#sdc_port_arr[*]}]=$dport
        echo server ${sdc_item[$name]} is trying on $dport...

        if [[ ${sdc_item[$ready]} == 'true' ]]; then
            sdc_listenport_result=(`listenPort $dport`)
            if [[ ${sdc_listenport_result[0]} == "0" ]]; then
                sdc_failed_arr[${#sdc_failed_arr[*]}]=${sdc_item[$name]}
                echo failed, timeOut
                exit 1
            else
                sdc_success_arr[${#sdc_success_arr[*]}]=${sdc_item[$name]}
                echo "success, server ${sdc_item[$name]} is running on $dport, ${sdc_listenport_result[0]}ports listened, spend `calcTime ${sdc_listenport_result[1]}`"
                sdc_spend_time=$[$sdc_spend_time + ${sdc_listenport_result[1]}]
            fi
        else
            sdc_success_arr[${#sdc_success_arr[*]}]=${sdc_item[$name]}
        fi
        echo ' '
    done

    echo all server is starting, waiting for running...

    sdc_check_all_server=`checkRunning ${sdc_port_arr[*]}`

    if [[ -n sdc_check_all_server ]]; then
        sdc_failed_arr=($sdc_check_all_server)
    fi

    end_time=$(date +%s)
    cost_time=$[$end_time - $start_time]
    echo success $[${#config_arr[*]} - ${#sdc_failed_arr[*]}], failed ${#sdc_failed_arr[*]}:${sdc_failed_arr[*]}  spend `calcTime $cost_time`
}


######################## 外部方法 ########################
# 载入镜像
loadDockerImages() {
    echo "loadDockerImages"

    configList=`getConf`

    # 解析二维数组
    configList=${configList//\ @\ /@}
    configList=${configList//\ /+}

    OLD_IFS="$IFS"
    IFS="@"
    config_arr=($configList)
    ldi_success_arr=()
    ldi_failed_arr=()
    ldi_port_arr=()
    ldi_spend_time=0
    IFS="$OLD_IFS"
    # 解析二维数组

    for ((ldi_i=1; ldi_i<${#config_arr[*]}; ldi_i++))
    do
        ldi_temp=${config_arr[$ldi_i]}
        ldi_temp=${ldi_temp//\+/\ }
        ldi_item=($ldi_temp)

        echo $ldi_temp
    done


}

# 创建挂载磁盘
makeFloder() {
    echo "makeFloder"
}

# 删除挂载磁盘
removeFloder() {
    echo "removeFloder"
}

# 创建容器
runDocker() {
    configPath=$1
    echo "runDocker"
    eval doDockerContainer run $configPath
}

# 启动容器
startDocker() {
    configPath=$1
    echo "startDocker"
    eval doDockerContainer start $configPath
}

# 重启容器
restartDocker() {
    configPath=$1
    echo "restartDocker"
    eval doDockerContainer restart $configPath
}

# 设置docker 用户名账号
dockerLogin() {
    echo "docker login -u tofflons@163.com -p Qwert1234567 tofflons-docker.pkg.coding.net"
}

# 停止一个容器
stopContainer() {
    docker stop $1
}

# 结束一个容器
killContainer() {
    docker kill $1
}

# 删除一个容器
removeContainer() {
    docker rm $1
}

# 删除镜像

# 运行protainer镜像
runPortainer() {
    docker run -d -p 7998:9000 --restart=always  -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data -v /public/portainerPublic:/public --name portainer-test  portainer/portainer
}

# 运行protainer镜像
startPortainer() {
    docker start portainer-test
}

# 重新跑一个容器 kill rm run
reRunContainer() {
    rPCName=$1
    echo `killContainer $rPCName`
    echo `removeContainer $rPCName`
    echo `runOneContainerByName $rPCName`
}

# main
main() {
    # 内部测试接口
    inList=('calcTime getConf listenPort doDockerContainer getOneConfByName')

    # 对外正式接口
    outList=('loadDockerImages makeFloder removeFloder runDocker startDocker restartDocker stopDocker stopContainer killContainer removeContainer runPortainer startPortainer reRunContainer')
    list=($inList $outList)

    if [[ -n $1 ]]; then
        command=$1
        mainPara=$2
        doCommand 

    else
        while ((1))
        do
            echo "请输入要执行的命令："
            read command

            # 问号显示所有命令
            if [[ $command == ? ]]; then
                echo ${list[*]}

            # exit退出程序
            elif [[ $command == 'exit' ]]; then
                echo 'byebye'
                exit 1
            else
            # 普通命令
                parsePara=($command)
                command=${parsePara[0]}
                mainPara=${parsePara[1]}
                doCommand
            fi

            echo ' '
        done
    fi
}

main $1 $2
