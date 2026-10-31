const feedFixture = '''<html><head><title>校园墙</title></head><body>
<header><nav><a href="/daily">今日小签</a><a href="/login">登录</a></nav></header>
<main><article class="card post"><div class="post-meta"><strong>匿名 #42</strong><span>2026-10-29 12:00:00</span></div>
<div class="tags"><a class="tag" href="/?q=闲聊">#闲聊</a></div>
<div class="post-content">秋天的校园真好看。<br><span class="post-color-blue">一起去散步吧！</span></div>
<div class="post-actions"><div class="left-actions"><span>点赞 3</span></div><div class="right-actions">
<form method="post" action="/post/42/share"><input type="hidden" name="csrf_token" value="fixture-token"><button type="submit">分享</button></form>
<a href="/post/42">评论 1</a></div></div></article></main></body></html>''';
const authFeedFixture = '''<html><head><title>校园墙</title></head><body>
<header><nav><a href="/my-posts">我的帖子</a><form action="/logout" method="post"><input name="csrf_token" type="hidden" value="fixture-token"><button type="submit">退出登录</button></form></nav></header>
<main><article class="card post"><div class="post-meta"><strong>匿名 #42</strong><span>2026-10-29 12:00:00</span></div>
<div class="post-content">测试内容</div><div class="post-actions"><div class="left-actions">
<form method="post" action="/post/42/like"><input type="hidden" name="csrf_token" value="fixture-token"><input type="hidden" name="next" value="/"><button class="like-button liked" type="submit">点赞 4</button></form></div>
<div class="right-actions"><form method="post" action="/post/42/favorite"><input type="hidden" name="csrf_token" value="fixture-token"><button type="submit">取消收藏</button></form>
<a href="/post/42">评论 1</a><a href="/post/42/report">举报</a></div></div></article></main></body></html>''';
const loginFixture =
    '''<html><head><title>登录</title></head><body><header><nav><a href="/login">登录</a></nav></header><main><h1>登录</h1>
<form method="post"><input type="hidden" name="csrf_token" value="fixture-token"><label>账号名</label><input name="username" required>
<label>密码</label><input name="password" type="password" required><button type="submit">登录</button></form></main></body></html>''';
const detailFixture = '''<html><head><title>匿名 #42</title></head><body><main>
<article class="card post"><div class="post-meta"><strong>匿名 #42</strong><span>2026-10-29 12:00:00</span></div>
<div class="post-content">秋天的校园真好看。</div><div class="left-actions">点赞 3</div></article>
<section class="comments-section"><h2>评论（1）</h2><article class="comment"><div class="comment-meta"><strong>匿名评论 #7</strong><span>2026-10-29 12:10:00</span></div>
<div class="comment-content">一起散步吧！</div><a href="/comment/7/report">举报评论</a></article></section></main></body></html>''';
const composeFixture =
    '''<html><head><title>发匿名帖</title></head><body><main><h1>发匿名帖</h1>
<form method="post"><input type="hidden" name="csrf_token" value="fixture-token"><input type="hidden" name="content_html" value="">
<div id="post-editor" contenteditable="true"></div><label>标签（可选）</label><input name="tags" maxlength="70">
<label><input type="checkbox" name="allow_share" checked>允许分享这篇帖子</label><button type="submit">提交投稿</button></form></main></body></html>''';
