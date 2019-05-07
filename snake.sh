#!/bin/bash

#高度不能超过47 光标无法移动
height=10
width=10
speed=0.2
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
                        index=$(($j * $height + $i))
                        if [ ${map[$index]} -eq 0 ]; then
                                echo -n "  "
                        elif [ ${map[$index]} -eq 1 ]; then
                                echo -ne "\033[41;31m[]\033[0m" 
			elif [ ${map[$index]} -eq 2 ]; then
				echo -ne "\033[47;37m[]\033[0m"
			elif [ ${map[$index]} -eq 3 ]; then
				echo -ne "\033[1m\033[41;31mHH\033[0m"
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
	y=$(($index / $height + $upSpace))

	value=$2
	echo -ne "\033[${y}B\033[${x}C\033[0m"
	if [[ $value -eq 0 ]]; then
		echo -n "  " 
	elif [[ $value -eq 1 ]]; then
		#1是身
		echo -ne "\033[41;31m[]\033[0m" 
	elif [[ $value -eq 2 ]]; then
		#2是种子
		echo -ne "\033[1m\033[47;36mFF\033[0m"
	elif [[ $value -eq 3 ]]; then
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
		if [[ ${map[$i]} -eq 0 ]]; then
			((random--))
			if [[ $random -eq 0 ]]; then
				seed=$i
				break
			fi
		fi
	done	

	map[$seed]=2
	paint $seed 2
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
	
	initPaint	
	generateSeed $size

	while :
	do
		#cho ${snake[*]}

		sleep $speed
	
		moveUp=$((${snake[0]} - $width))
		moveDown=$((${snake[0]} + $width))
		moveLeft=$((${snake[0]} - 1))
		moveRight=$((${snake[0]} + 1))
			
		snakeSize=${#snake[@]}
		snakeTail=${snake[@]:$snakeSize-1}	

		# == 和 = 功能不同	
		if [[ $direction = "w" && $moveUp -ge 0 && ($moveUp = $snakeTail || ${map[$moveUp]} -ne 1) ]]; then
			snake=($moveUp ${snake[*]})
		#	map[$moveUp]=1
		elif [[ $direction = "s" && $moveDown -lt ${#map[@]} && ($moveDown = $snakeTail || ${map[$moveDown]} -ne 1) ]]; then
			snake=($moveDown ${snake[*]})
		#	map[$moveDown]=1
		elif [[ $direction = "a" && $moveLeft -ge 0 && $(($moveLeft % $width)) -ne $(($width - 1)) || ($moveLeft = $snakeTail && ${map[$moveLeft]} -ne 1) ]]; then
			snake=($moveLeft ${snake[*]})
		#	map[$moveLeft]=1
		elif [[ $direction = "d" && $moveRight -lt ${#map[@]} && $(($moveRight % $width)) -ne 0 || ($moveRight = $snakeTail && ${map[$moveRight]} -ne 1) ]]; then
			snake=($moveRight ${snake[*]})
		#	map[$moveRight]=1
		else
			continue
		fi
		

		snakeSize=${#snake[@]}
		snakeTail=${snake[@]:$snakeSize-1}
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

		if [[ $snakeHead -eq $seed ]]; then
			((size--))
			generateSeed $size
			
		else 
			#去除尾
			snake=(${snake[@]:0:$snakeSize-1})
			if [[ $snakeHead -ne $snakeTail ]]; then	
				map[$snakeTail]=0
				paint $snakeTail 0
			fi
		fi
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




