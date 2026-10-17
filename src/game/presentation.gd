extends RefCounted
## State-driven prose. Reading a paragraph never rolls dice or resolves a card.
const NAMES = {"zhang":"老张","elin":"艾琳","ajie":"阿杰","sofia":"索菲亚","sister":"妹妹"}
const DISPLAY_NAMES = {
	"captain":"队长","zhang":"老张","elin":"艾琳","ajie":"阿杰","sofia":"索菲亚","sister":"妹妹",
	"xuning":"许宁","chenchuan":"陈川","duheng":"杜衡","linyue":"林悦","cenbai":"岑柏","luzhi":"陆芷",
	"repair":"维修","medical":"医疗","scout":"侦察","logistics":"后勤","water":"饮水","food":"食物","fuel":"燃料","medicine":"药品","parts":"零件","tea":"茶仪式","incense":"香仪式",
	"accounts":"清账","aid":"急救","none":"不行动","safe":"安全","resource":"资源","unknown":"未知","stay":"主动停留","quiet":"低噪音","fast":"快速","detour":"绕行",
	"south":"南边定居点","east":"东岸聚落","guild":"公路商会","independent":"独立补给","shadow":"巡游路线","frequency":"核查旧频段","rescue":"救援准备","continue":"继续原计划",
	"rest":"全队休息","care":"照料","gather":"当地搜集","read":"阅读","teach":"教学","self_study":"应急自学","record":"记录","new_car":"修复废车","second_car":"购买副车","install":"安装配件","remove":"拆除配件","exchange_book":"交换书籍","burn_book":"焚书取暖","notebook":"笔记本"
}
const DAY_PLANS = {
	1:"先清点物资，安排一次晨间准备，再决定今天的路线。每天最多处理两项主要事务，营地只安排一次行动。",
	2:"旧频段里有一段没有听清的声音。可以核查，也可以先联系东岸或寻找补给。",
	3:"今天要在安全、补给和未知路段之间取舍。路段供应饮水与食物。",
	4:"前方废弃医疗站有两名幸存者。只能邀请其中一人同行；两人都不加入也可以继续。",
	5:"电台传来妹妹正式求救的信号。第10天是救援期限；还没核查的旧频段，今天可以补核。",
	6:"留意燃料、零件和可修复的废车。也给队员留出休息、学习和备份记录的时间。",
	7:"旧水塔下有两名候选同伴，只能邀请一人。增加人口后，今晚的配给也会增加。",
	8:"今天要决定是否侦察南边入口。侦察消耗燃料4、1小时和一项主要事务，是救援准备的一部分。",
	9:"明天救援前，最后检查情报、主边进度、医疗与侦察岗位，以及燃料12、零件5和药品2。岑柏会在停歇点出现。",
	10:"救援期限已到。按实际准备选择进入、突破或放弃；救援费用替代今天的普通行驶费用。",
	11:"回头看看队伍里还在的人。按实际人数准备配给，先处理伤员和累积的疲劳。",
	12:"从今天起，可以在实际到达后办理定居、并入或商路登记。早期失车后仍在徒步的队伍，今晚必须完成补救或庇护。",
	13:"上一轮选择留下的代价还在。检查岗位、配给和车况，再决定继续还是完成目标。",
	14:"留意承诺到期、私藏和群体分歧。知识需要备份，分歧也需要及时回应。",
	15:"已经接触公路商会的队伍可以采购第二辆车。先算清购车成本和之后的燃料，再决定如何补救。",
	16:"继续履行已经作出的选择。新的补救不会抹去过去的伤亡、掠夺与互斥招募。",
	17:"最后几个行程日到了。核对实际距离、阵营关系和剩余配给，看看还有哪些目标可行。",
	18:"为最后的去向采取行动。能定居就实际办理，能登记商路就完成登记；也可以沿已经验证的规律继续。",
	19:"到达、交易、停留，或者再守住队伍一天。具备条件的目标今天仍可完成。",
	20:"这是最后一个行程日。完成可达的目标并结算今晚的配给；旅途不会延续到第21天。"
}

static func day_plan(r) -> String:
	return DAY_PLANS.get(int(r.s.day),"")

static func readable(value: String) -> String:
	var pattern = RegEx.new(); pattern.compile("[A-Za-z_][A-Za-z_0-9]*")
	var result = ""; var cursor = 0
	for token in pattern.search_all(value):
		result += value.substr(cursor,token.get_start()-cursor)+str(DISPLAY_NAMES.get(token.get_string(),token.get_string()))
		cursor = token.get_end()
	return result+value.substr(cursor)

static func journal(lines: Array) -> String:
	var result: Array[String] = []
	for line in lines: result.append(readable(str(line)))
	return "\n".join(result)

static func morning(r) -> String:
	var s = r.s
	var night = s.facts.get("last_night",{})
	var watcher = str(night.get("watcher",""))
	var opening = "你把火压下去。"
	if r.living(watcher):
		var words = "他后来睡着了。" if night.get("injured",false) else ("车外那一圈，还没看完。" if night.get("footprints",false) else ("少的那份，我没再摆出来。" if night.get("departed",false) else "后半夜没动静。"))
		opening = r.person(watcher).name+"把火压下去，说了一句：「"+words+"」"
	var lines = ["天没亮透。",opening,"火灰还是热的。"]
	if int(s.day) == 1 and night.is_empty():
		lines = ["天没亮透。废弃加油站的雨棚下，五个人围着车清点物资。","锈死的加油机旁，油桶、药箱和账本已经摆好。先安排一次准备，再决定出发的路线。"]
	var dur = r.car().get("durability",100)
	if r.living("zhang"):
		lines.append("老张蹲在车前：「"+("先别点火。这回得修好再走。" if dur <= 20 else ("能走，和能走完，不是一回事。" if dur <= 40 else ("今天让别人接一段。我手有点慢了。" if r.person("zhang").fatigue >= 60 else "工具在原来的地方。你定路。")))+"」")
	if r.living("elin"):
		var hp = r.lowest().get("health",100)
		lines.append("艾琳把药箱放在膝上：「"+("先看他。路线等一会儿。" if hp <= 30 else ("伤没过去，只是昨晚没再说。" if hp <= 40 else ("我今天要少守一轮，不然容易看错。" if r.person("elin").fatigue >= 60 else ("这点药，经不起我们再答应一件事。" if s.resources.medicine < 2 else "人都在。今天还是按人数分。"))))+"」")
	if r.living("ajie"):
		if int(s.day) == 1 and night.is_empty(): lines.append("阿杰把地图摊在引擎盖上：「先从这里开始画。」")
		else: lines.append("阿杰把地图折回昨天那一道：「"+("这条线我看了三遍，得换个人再看一遍。" if r.person("ajie").fatigue >= 60 else ("这里有两条痕。不是地图上那两条。" if s.facts.get("yesterday_unknown_failure",false) else "昨天走过的，我划掉了。"))+"」")
	if r.living("sofia"):
		lines.append("索菲亚先数杯子，再数袋子：「"+("有个人不想把明天那份放车上了。" if r.people().any(func(m): return m.id != "captain" and m.trust <= 20) else ("我能念出来，不能替我们多念一份。" if r._eligible_shortage() else ("这一栏对不上。差的不是字。" if not s.facts.get("theft_ledger",{}).is_empty() else "账和车上的东西，是一样的。")))+"」")
	return "\n\n".join(lines)

static func story(r) -> String:
	var s = r.s
	var lines = []
	if s.phase == "morning": lines.append(morning(r))
	var node = r.content.story.get(str(s.day),{})
	if not node.is_empty():
		lines.append("[b]"+node.title+"[/b]")
		for line in node.lines:
			if "：" not in line or line.begins_with("①"): continue
			var name = line.get_slice("：",0)
			if name not in ["队长","电台"] and not NAMES.values().has(name): continue
			if NAMES.values().has(name):
				var actor = r.person(str(NAMES.find_key(name)))
				if not r.living(str(NAMES.find_key(name))) or actor.health < 30 or actor.fatigue >= 95: continue
			# Arrival and three observations are facts, not granted by the date.
			if int(s.day) == 12 and name in ["索菲亚","阿杰"] and s.legs < 8 and s.position != "避难点": continue
			if int(s.day) == 18 and name == "阿杰" and s.observations < 3: continue
			lines.append(line)
	if s.phase == "stop" and int(s.day) in [4,7,9]:
		var stage = {4:"四 第4天 医疗站的两个人",7:"五 第7天 水塔下的地图",9:"六 第9天 岑柏与最后清点"}[int(s.day)]
		for line in str(r.content.stages[stage]).split("\n"):
			if line.begins_with("固定") or line.begins_with("实际加入") or line.begins_with("①") or line.begins_with("当晚清点") or line.begins_with("岑柏固定"): continue
			if int(s.day) == 9 and line.begins_with("索菲亚") and r.people().size() < 8: continue
			lines.append(filter_absent(r,line))
	if s.phase == "night": lines.append("今天走过的，已经在身后。\n明天能不能走，留在这些东西里面。")
	return "\n\n"+"\n\n".join(lines) if not lines.is_empty() else ""

static func filter_absent(r, value: String) -> String:
	var result = value
	for id in NAMES:
		if r.living(id) and r.person(id).health >= 30 and r.person(id).fatigue < 95: continue
		var re = RegEx.new()
		re.compile(NAMES[id]+"[^「“\\n]*?[「“][^」”]*[」”][。！？]?")
		result = re.sub(result,"",true)
		# Also remove a short action attributed to an absent person.
		re.compile(NAMES[id]+"[^。！？\\n]*[。！？]")
		result = re.sub(result,"",true)
	return result.strip_edges()

static func card(r, id: String, owner: String = "") -> String:
	var data = r.card_data(id)
	if id in r.ENV_EVENTS: return data.text
	if id == "T13":
		var ledger = r.s.facts.get("theft_ledger",{})
		return "索菲亚摊开账本：「这一笔已经少了。不是风险，是账上真实扣掉的东西。」\n\n待追索："+r.cost_text({str(ledger.get("resource","food")):ledger.get("amount",0)})
	if id == "S04":
		var result = "艾琳站在灯下：「一支。够一个人。」" if r.living("elin") else "最后一支药放在灯下。"
		if r.living("zhang") and r.person("zhang").health <= 40:
			result += "\n\n老张：「留着。"+("你妹妹比我有用。" if r.s.day < 10 else ("她还没好。" if r.s.sister == "alive" else "后面有人要用。"))+"」"
		if r.living("sofia"): result += "\n\n索菲亚合上账本。"
		return result
	if id in ["N-X03","N-X04","N-X05"] and owner == "sister":
		return {"N-X03":"妹妹拿着杯子，没往前挤：「你别把我那份算成你剩下的。」","N-X04":"妹妹把工具摆整齐：「别只是让我坐里面。」","N-X05":"妹妹看向空位：「你可以叫我的名字。这里不只有我是谁的妹妹。」"}[id]
	var lines = []
	for block in str(data.text).split("\n\n"):
		if block.begins_with("合格") or block.begins_with("①") or block.begins_with("入场"): continue
		lines.append(filter_absent(r,block))
	if id == "N-X02": lines.append("本局剩余验证次数：%d；绕开或失败将清零连续遵规。" % (3-int(r.s.card_history.get(id,{}).get("count",0))))
	return "\n\n".join(lines)

static func inquiry(r, id: String, option: int, owner: String) -> String:
	var options = r.card_data(id).get("options",[])
	if option < 0 or option >= options.size(): return ""
	var result = str(options[option].raw)
	if id == "T01":
		var history: Array[String] = []
		for row in r.s.history:
			for line in row.get("log",[]):
				if "前桥" in str(line) or "维修承诺" in str(line): history.append("第%d天：%s" % [row.day,line])
		for line in r.s.daily.log:
			if "前桥" in str(line) or "维修承诺" in str(line): history.append("今天："+str(line))
		result += "\n已有记录：\n"+("\n".join(history.slice(maxi(0,history.size()-5))) if not history.is_empty() else "行程记录中暂未记载此前提醒的日期。")
	else:
		var member = r.person(owner)
		if not member.is_empty(): result += "\n当前健康%.0f、疲劳%.0f、信任%.0f、好感%.0f。" % [member.health,member.fatigue,member.trust,member.like]
	return result

static func ending(r) -> String:
	var s = r.s
	var paragraphs = []
	for block in str(r.content.endings[s.ending].text).split("\n\n"):
		if block.begins_with("判定：") or block.begins_with("未形成公开制度时") or block.begins_with("残信已失去时"): continue
		paragraphs.append(block)
	var result = "\n\n".join(paragraphs)
	if s.ending == "E17":
		result = result.split("再走不能正文。")[1] if r.living("captain") else result.split("再走不能正文。")[0].trim_prefix("状态耗尽正文。")
	if s.ending == "E08" and not s.facts.get("public_rules",false):
		result = result.replace("有人说起那条大家都知道的规矩。另一个人补了后半句。没有谁从头到尾说完，却没有一句漏掉。","我们把路上一起做过的事讲了一遍。谁照料过谁，谁把消息送到，哪一次分东西以后还缺一份。关卡的人听着，没有打断。")
	var record_keeper = _role_name(r,"logistics")
	result = result.replace("[记账者]",record_keeper).replace("[实际仍在队的记录者]",record_keeper).replace("[维修者]",_role_name(r,"repair")).replace("[领路者]",_role_name(r,"scout")).replace("[实际日数]",str(s.day))
	var dead = s.members.filter(func(m): return not m.alive and "repair" in m.get("lost_roles",[]))
	result = result.replace("[死者]",dead.back().name if not dead.is_empty() else "逝去的队友").replace("[当前必需任务：修复不可通行车况／救治正恶化的重伤员]","修复已经无法通行的车")
	result = result.replace("车还在时，车门开着；车已丢失时，路边只剩那些没背完的行囊。","路边只剩那些没背完的行囊。" if r.on_foot() else "车门开着。")
	result = result.replace("车还在时，钥匙放在桌上；车不在时，也没有人再问能不能找回来。","也没有人再问能不能找回车。" if r.on_foot() else "钥匙放在桌上。")
	result = result.replace("车还在时，车去了远处；车不在时，人走进了别的脚印。","人走进了别的脚印。" if r.on_foot() else "车去了远处。")
	result = result.replace("车还在就停在站外，车不在，行囊放到床边。","行囊放到了床边。" if r.on_foot() else "车停在了站外。")
	if s.ending == "E10":
		result = result.replace("有第二辆车时，两边按实际分配的车和物品离开；只有一辆时，一边拿着车钥匙，另一边带着能背的东西，去已经确认可达的近处安置点。没有另一辆车凭空发动。","两边按实际分配的车和物品离开。" if r.cars().size() > 1 else "一边拿着车钥匙，另一边带着能背的东西沿来路离开。账上没有替他们补写平安的地址。")
	return result.strip_edges()

static func _role_name(r, role: String) -> String:
	var qualified = r.qualified(role)
	if not qualified.is_empty(): return qualified[0].name
	return "我" if r.living("captain") else "留下记录的人"

static func epilogue(r) -> String:
	var s = r.s; var id = r.epilogue_id()
	var blocks = str(r.content.epilogues[id].text).split("\n\n")
	var captain_alive = r.living("captain")
	if id == "S01":
		var prefix = "安全离队版：" if s.sister == "safe_departed" else ("E12下短版：" if s.ending == "E12" else ("在队版：" if captain_alive else "主角已死变体："))
		for block in blocks:
			if block.begins_with(prefix): return block.trim_prefix(prefix)
	if id == "S02":
		var lines = [blocks[1],blocks[2]]
		lines.append(blocks[3] if captain_alive else "后来者看见那两行日期，知道她曾经被带出那里，也知道旅途没有替她守到最后。")
		return "\n\n".join(lines)
	if id == "S03":
		return "\n\n".join([blocks[1],blocks[2],blocks[3],blocks[4]]) if captain_alive else "确认人的署名仍在。残存的声音不改变那一行记录。"
	if id == "S04":
		if s.sister == "rescued_unknown": return "她离开那天，账上写了时间。没有划掉获救那一行，也没有补上平安的地址。后来电台开着，我们只知道最后一次看见她时，她还活着。再往后的事，没有消息。" if captain_alive else "最后一张记录，只确认到她离开的那天。"
		var line = "她的名字后面没有划线，只写了最后一次收到信号的日子。" if "coordinates" in s.clues else "她的名字后面没有划线。没有收到正式信号，只留了名字，没有补日期。"
		var result = line+"\n\n"+blocks[2]+"\n\n"+blocks[3]
		if captain_alive: result += "\n\n我有时摸一下放那页纸的口袋。"+("摸到折痕。" if s.notebook else "摸到的是空的。")
		return result
	if id == "S05": return "\n\n".join([blocks[1],blocks[2],blocks[3]]) if captain_alive else "记录留下的不是没听见，也不是电台故障。那天的选择仍在那里，不能再由任何人改成别的原因。"
	if id == "S06": return "\n\n".join([blocks[1],blocks[2],blocks[3],blocks[4]])
	return ""
