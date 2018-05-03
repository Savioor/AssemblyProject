import re
'''
This sneakiest code known to the 10-th grade assembly student.
Replaces all .if and .elif and .endif with proper jmp and cmp commands.
Made by Alexey Shapovalov.
'''

# Works and tested
def fileToArray(fileName: str) -> list:
    file = open(fileName, "r")
    retArr = []
    retArr.append(file.readline())
    while retArr[-1] != "":
        retArr.append(file.readline())
    retArr.pop(-1)
    file.close()
    return retArr


def arrayToFile(fileName: str, toWrite: list) -> None:
    file = open(fileName, "w")
    for line in toWrite:
        file.write(line)
    file.close()

#     Signature Map:
#
#   xxx-#(c);
#
#   name - index - ( - condition raw - ) - ; - comment

def exchangeIfWithSignature(fileArray: list) -> list:
    nextIf = 0
    openIfs = []
    newArr = []
    for line in fileArray:
        if re.search("\t*?\.if", line):
            toAdd = ""
            toAdd += re.search("\t*?\.", line).string + "IFF"
            toAdd += re.search("(?<=\.if).*?", line).string
            try:
                toAdd += re.search(";.*", line).string
            except:
                pass
            newArr.append(toAdd)
            print("new if opened #{}".format(nextIf))
            openIfs.append(nextIf)
            nextIf += 1
        elif re.search("\t*?\.elseif", line):
            toAdd = ""
            toAdd += re.search("\t*?\.", line).string + "ELF"
            toAdd += re.search("(?<=\.elseif).*?", line).string
            try:
                toAdd += re.search(";.*", line).string
            except:
                pass
            newArr.append(toAdd)
            print("new elseif made #{}".format(openIfs[-1]))
        elif re.search("\t*?\.else", line):
            toAdd = ""
            toAdd += re.search("\t*?\.", line).string + "IFF"
            try:
                toAdd += re.search(";.*", line).string
            except:
                pass
            newArr.append(toAdd)
            print("new else made #{}".format(openIfs[-1]))
        elif re.search("\t*?\.endif", line):
            toAdd = ""
            toAdd += re.search("\t*?\.", line).string + "IFF"
            try:
                toAdd += re.search(";.*", line).string
            except:
                pass
            newArr.append(toAdd)
            print("if closed #{}".format(openIfs.pop(-1)))
        else:
            newArr.append(line)
    fileArray = newArr
    return fileArray

def exchangeSignatureWithCode(fileArray: list) -> list:
    pass

n = input("enter file name >>> ")

arrayToFile("test2.txt", exchangeIfWithSignature(fileToArray(n)));

#arrayToFile(n, exchangeSignatureWithCode(exchangeIfWithSignature(fileToArray(n))))
