#!/bin/bash

#高度不能超过47 光标无法移动
height=10
width=10
speed=0.02
upSpace=10
leftSpace=10

map=()

snake=()

SILEFT=25
SIRIGHT=26
SIUP=27
SIDOWN=28

#隐藏光标
echo -ne "\033[?25l"


for ((i=0; i < $(($height * $width)); i++))
do
	map[$i]=0;
done

function myExit()
{
	kill -15 $pid
	stty $sTTY
	echo -ne "\033[?25h"
	clear
	exit
}

function paintUpDown()
{
	for ((i=0; i < $(($width + 2)); i++))
	do
		echo -ne "\033[1m\033[42;32m=="
	done
	echo -e "\033[0m"	
}

function initPaint()
{
	
	mapPaint=()
	#由于shell的数组太垃圾，传递会丢失下标所以重新附值	
	k=0
	for var in $1
	do
		((mapPaint[k]=var))
		((k++));
	done

	border="\033[1m\033[42;32m||\033[0m"
	
	for ((i=1; i < $upSpace; i++))
	do
		echo ""
	done

	for ((i=1; i <= $leftSpace-2; i++))
	do
		echo -n " "
	done
	paintUpDown
	
	#内容
        for ((j=0; j < $height; j++))
        do
		for ((i=1; i <= $leftSpace-2; i++))
		do
			echo -n " "
		done	
		echo -ne "$border"

                for ((i=0; i < $width; i++))
                do
                        index=$(($j * $width + $i))
                        if [ ${mapPaint[$index]} -eq 0 ]; then
                                echo -n "  "
                        elif [ ${mapPaint[$index]} -eq 1 ]; then
                                echo -ne "\033[41;31m[]\033[0m" 
			elif [ ${mapPaint[$index]} -eq 2 ]; then
				echo -ne "\033[47;37m[]\033[0m"
			elif [ ${mapPaint[$index]} -eq 3 ]; then
				echo -ne "\033[1m\033[41;31mHH\033[0m"
			else
				echo -n ${mapPaint[$index]}
                        fi
                done
                echo -e $border
        done
	
	for ((i=1; i <= $leftSpace-2; i++))
	do
			echo -n " "
	done
	paintUpDown

	#光标回到第一行
	echo -ne "\033[$(($height + $upSpace + 1))A\033[0m"
}

#绘制
function paint() 
{
	index=$1
	x=$((($index % $width) * 2 + $leftSpace))
	y=$(($index / $width + $upSpace))

	value=$2
	echo -ne "\033[${y}B\033[${x}C\033[0m"
	if [[ $value = 0 ]]; then
		echo -n "  " 
	elif [[ $value = 1 ]]; then
		#1是身
		echo -ne "\033[41;31m[]\033[0m" 
	elif [[ $value = 2 ]]; then
		#2是种子
		echo -ne "\033[1m\033[47;36mFF\033[0m"
	elif [[ $value = 3 ]]; then
		#3是头
		echo -ne "\033[1m\033[41;31mHH\033[0m"
	fi
	echo -ne "\033[${y}A\033[$(($x + 2))D\033[0m"
}

function move()
{
	pid=$1

	sTTY=`stty -g`

	trap "myExit" INT TERM 
	
	operation=0
	while :
	do
		
		read -s -n 1 direction
		if [[ $direction = "w" && $operation != $SIDOWN ]]; then
			operation=$SIUP
		elif [[ $direction = "s" && $operation != $SIUP ]]; then
			operation=$SIDOWN
		elif [[ $direction = "a" && $operation != $SIRIGHT ]]; then
			operation=$SILEFT
		elif [[ $direction = "d" && $operation != $SILEFT ]]; then
			operation=$SIRIGHT
		else
			continue
		fi
		
		#echo "方向:$direction 操作:$operation"
			
		#f [[ operation != 0 ]]; then
			#发送信号
			kill -$operation $pid
		#i
	done
}

function canMove()
{
	#0为true 1为false
	if [ $1 -lt 0 ]; then
		return 1
	elif [ $1 -ge ${#map[@]} ]; then
		return 1
	elif [ ${map[$1]} -eq 1 ]; then
		return 1
	fi
	return 0
}

function generateSeed()
{
	random=$((RANDOM % $1 + 1))
	seed=0
	for ((i=0; i < ${#map[@]}; i++))
	do
		if [[ ${map[$i]} = 0 ]]; then
			((random--))
			if [[ $random = 0 ]]; then
				seed=$i
				break
			fi
		fi
	done	

	map[$seed]=2
	paint $seed 2
}

#保存移动的路劲
step=()
#复制地图
cpMap=()
#复制蛇
cpSnake=()

#判断种子的权值填充位置是否正确
function judgeSeedPathValue()
{
	if ((pathy < 0 || pathy >= height));then
		return
	fi
	pathIndex=$((pathy * width))
	pathLeft=$((seedx - pathWidth))
	if ((pathLeft >= 0 && cpMap[pathIndex + pathLeft] == 0));then
		((cpMap[pathIndex + pathLeft]=pathValue+100))
	fi
	
	pathRight=$((seedx + pathWidth))
	if ((pathRight < width && cpMap[pathIndex + pathRight] == 0));then
		((cpMap[pathIndex + pathRight]=pathValue+100))
	fi
}

#初始化种子周围的节点权值 离种子越近值越小 从100开始计算，避免重复值
function initSeedPathValue()
{
	seedx=$((seed % width))
	seedy=$((seed / width))
	maxPathValue=$((height + width - 1))
	for((pathValue=1; pathValue <= maxPathValue; pathValue++))
	do
		#先从种子的上半部分初始化
		for((pathy=seedy - pathValue, pathWidth=0; pathy <= seedy; pathy++, pathWidth++))
		do	
			judgeSeedPathValue
		done

		#下半部分
		for((pathy=seedy + pathValue, pathWidth=0; pathy > seedy; pathy--, pathWidth++))
		do
			judgeSeedPathValue
		done
	done
}

#复制
function copyMap()
{
	#复制地图
	for ((k=0; k < height * width; k++))
	do
		cpMap[$k]=${map[$k]}
	done
	#复制蛇	
	for ((k=0; k < ${#snake[@]}; k++))
	do
		cpSnake[$k]=${snake[$k]}
	done
}

#移动的步数
stepSize=0
#路劲的长度下标
cpStepSize=0
#计算移动到种子处
getSeedFlag=0

function moveStep()
{
	#shell非常难用
	#已经找到种子了		
	if ((getSeedFlag == 1)); then
		return
	fi

	local cpHead=$1
	cpMap[$cpHead]=1
	if ((cpStepSize != -1)); then
		#刚开始时从头部开始所以不能赋值		
		step[$cpStepSize]=$2	
	fi
	((cpStepSize++))

	local stepDir=([0]=a [1]=d [2]=w [3]=s)
	local stepValue=([0]=1 [1]=1 [2]=1 [3]=1)
	#echo -ne "$cpHead 结点"
	local cpHeadx=$((cpHead % width))
	local cpHeady=$((cpHead / width))
		
	#!不能使用(())对字符数组进行赋值 真的难用

	#要根据上面abcd的排序来写
	if ((cpHeadx - 1 >= 0));then
		((stepValue[0]=cpMap[cpHead-1]))
	fi
	if ((cpHeadx + 1 < width));then
		((stepValue[1]=cpMap[cpHead+1]))
	fi
	if ((cpHeady - 1 >= 0 ));then
		((stepValue[2]=cpMap[cpHead-width]))
	fi
	if ((cpHeady + 1 < height ));then
		((stepValue[3]=cpMap[cpHead+width]))
	fi
	#	for((k=0; k < 4; k++))
	#	do 
	#		echo -ne "${stepDir[$k]} : ${stepValue[$k]};   "
	#	done 
	
	#echo ${cpMap[@]}

	#判断下一步是不是种子
	for((k=0 ;k < 4; k++))
	do
		if ((stepValue[k]==2)); then	
			getSeedFlag=1
			step[$cpStepSize]=${stepDir[$k]}
			#记录最长的步数
			((stepSize=cpStepSize+1))
			return
		fi
	done

	
	#排序
	for((k1=0; k1 < 4; k1++))
	do
		for((k2=4-1; k2 > k0; k2--))
		do
			if ((stepValue[k2] < stepValue[k2-1]));then
				((valueT=stepValue[k2]))
				((stepValue[k2]=stepValue[k2 - 1]))
				((stepValue[k2 - 1]=valueT))

				#垃圾shell 字符串不能使用(())
				dirT=${stepDir[$k2]}
				stepDir[$k2]=${stepDir[$((k2 - 1))]}
				stepDir[$((k2 - 1))]=$dirT
			fi
		done
	done

	#这个地方很恶心还是和它这个local有关	
	local kL=0
	#把排好序的操作便历
	for((kL=0; kL < 4; kL++)) 
	do
		if [[ ${stepDir[$kL]} = "a" && ${stepValue[$kL]} -ge 100 ]] ;then
			#往左
			moveStep $((cpHead - 1)) ${stepDir[$kL]}
		elif [[ ${stepDir[$kL]} = "d" && ${stepValue[$kL]} -ge 100 ]] ;then
			#往右
			moveStep $((cpHead + 1)) ${stepDir[$kL]}
		elif [[ ${stepDir[$kL]} = "w" && ${stepValue[$kL]} -ge 100 ]] ;then
			#往上
			moveStep $((cpHead - width)) ${stepDir[$kL]}
		elif [[ ${stepDir[$kL]} = "s" && ${stepValue[$kL]} -ge 100 ]] ;then
			#往下
			moveStep $((cpHead + width)) ${stepDir[$kL]}
		fi
	done

	((cpStepSize--))
}

#漫步者
function wander()
{
	snakeHead=${snake[0]}
	snakeHeadx=$((snakeHead % width))
	snakeHeady=$((snakeHead / width))
	local stepDir=([0]=a [1]=d [2]=w [3]=s)
	
	if ((snakeHeadx > seedx)); then
		stepDir[1]=${stepDir[0]}
		stepDir[0]=d
	fi
	if ((snakeHeady < seedy)); then
		stepDir[2]=${stepDir[1]}
		stepDir[1]=${stepDir[0]}
		stepDir[0]=w
	fi
	if ((snakeHeady > seedy)); then
		stepDir[3]=${stepDir[2]}
		stepDir[2]=${stepDir[1]}
		stepDir[1]=${stepDir[0]}
		stepDir[0]=s
	fi
	
	for((k=0; k < 4; k++)) 
	do	
		if ((stepSize >= 1)); then
			return
		fi		
		if [[ ${stepDir[$k]} = "a" && $snakeHeadx -gt 0 && ${map[$((snakeHead - 1))]} = 0 ]] ;then
			#往左
			step[0]="a"
			stepSize=1
		elif [[ ${stepDir[$k]} = "d" && $snakeHeadx -lt $((width - 1)) && ${map[$((snakeHead + 1))]} = 0 ]] ;then
			#往右
			step[0]="d"
			stepSize=1
		elif [[ ${stepDir[$k]} = "w" && $snakeHeady -gt 0 && ${map[$((snakeHead - width))]} = 0 ]] ;then
			#往上
			step[0]="w"
			stepSize=1
		elif [[ ${stepDir[$k]} = "s" && $snakeHeady -lt $((height - 1)) && ${map[$((snakeHead + width))]} = 0 ]] ;then
			#往下
			step[0]="s"
			stepSize=1
		fi

	done

}

#	time=0
function moveSeek()
{
	copyMap
	initSeedPathValue
#	initPaint "${cpMap[*]}"
	#总长度重置
	stepSize=0
	cpStepSize=-1
	#重新设定没有找到种子
	getSeedFlag=0

#	((time++))
#	if ((time == 2)); then
#		for((k=0; k < height * width; k++))
#		do
#			echo -ne "${cpMap[$k]} ";
#		done
#		echo -ne ${cpSnake[@]}
#	fi	
	
	moveStep ${cpSnake[0]} "c"
	if ((getSeedFlag == 0)); then 
		#漫步策略，没有找到种子则往离种子最远的步迈一小步
		wander
	fi
}


#必胜走法
function winStep()
{
	stepSize=$((height * width))	
	for((k1=0; k1 < height; k1++))
	do
		for((k2=0; k2 < width - 2; k2++))
		do
			index=$((k1 * (width - 1) + k2))
			if ((k1 % 2 == 0)); then		
				step[$index]=d
			else
				step[$index]=a
			fi
		done
		index=$((k1 * (width - 1) + width - 2))
		if ((k1 != height - 1)); then
			step[$index]=s
		else
			step[$index]=a	
		fi
	done

	for((k=0; k < height-1; k++))
	do
		index=$((k + height * (width - 1)))
		step[$index]=w
	done
	index=$((height - 1 + height * (width - 1)))
	step[$index]=d
}

function main()
{
	
	direction=0	
	
	trap "direction=w" $SIUP
	trap "direction=s" $SIDOWN
	trap "direction=a" $SILEFT
	trap "direction=d" $SIRIGHT 
	
	#初始位置
	size=$((${#map[@]} - 1))
	snake[0]=$((RANDOM % $size))
	map[${snake[0]}]=3
	
	initPaint "${map[*]}"
	generateSeed $size

	#winStep
	while :
	do
		#cho ${snake[*]}
		#查找路劲
		moveSeek
		
		
		for((k=0; k < stepSize; k++))
		do
			direction=${step[$k]}
			sleep $speed
		
			moveUp=$((${snake[0]} - $width))
			moveDown=$((${snake[0]} + $width))
			moveLeft=$((${snake[0]} - 1))
			moveRight=$((${snake[0]} + 1))
			
			# == 和 = 功能不同	
			if [[ $direction = "w" && $moveUp -ge 0 && ${map[$moveUp]} -ne 1 ]]; then
				snake=($moveUp ${snake[*]})
			#	map[$moveUp]=1
			elif [[ $direction = "s" && $moveDown -lt ${#map[@]} && ${map[$moveDown]} -ne 1 ]]; then
				snake=($moveDown ${snake[*]})
			#	map[$moveDown]=1
			elif [[ $direction = "a" && $moveLeft -ge 0 && $(($moveLeft % $width)) -ne $(($width - 1)) && ${map[$moveLeft]} -ne 1 ]]; then
				snake=($moveLeft ${snake[*]})
			#	map[$moveLeft]=1
			elif [[ $direction = "d" && $moveRight -lt ${#map[@]} && $(($moveRight % $width)) -ne 0 && ${map[$moveRight]} -ne 1 ]]; then
				snake=($moveRight ${snake[*]})
			#	map[$moveRight]=1
			else
				continue
			fi
		

		
			snakeTail=${snake[@]:(-1):1}
			snakeHead=${snake[0]}
		
		#echo -n "${snake[0]},seed=$seed         "
		#echo -ne "\033[100D\033[0m"
			
			map[$snakeHead]=1
			if [[ ${#snake[@]} -gt 1 ]]; then
				paint $snakeHead 3
				paint ${snake[1]} 1
			else
				paint $snakeHead 3
			fi
	
			if [[ $snakeHead = $seed ]]; then
				((size--))
				generateSeed $size
			
			else
				#去除尾
				snake=(${snake[@]:0:$((${#snake[@]} - 1))})
				map[$snakeTail]=0
				paint $snakeTail 0
			fi
		done
	done
}

main &
move $!

<<!
for ((k=0; k < $(($height * $width)); k++))
do
	map[$k]=1
	paint
	map[$k]=0
done
!





