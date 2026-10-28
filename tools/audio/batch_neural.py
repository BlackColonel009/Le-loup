"""Batch residual predictions, keeping the fixed-batch talker independent per item.

Each prompt retains its own cache, RNG, reference and EOS. No audio splicing.
"""
import numpy as np
from inference import _sample, _apply_repetition_penalty, N_GROUPS


def generate_batch(pipe, texts, reference, transcript, seeds):
    prompts = []
    original = pipe._ar_loop
    def capture(*args):
        prompts.append(args)
        return np.zeros((1, N_GROUPS), np.int64)
    pipe._ar_loop = capture
    try:
        for text, seed in zip(texts, seeds):
            pipe.generate(text, language='French', ref_audio=str(reference),
                ref_text=transcript, max_new_tokens=350, seed=seed, verbose=False)
    finally:
        pipe._ar_loop = original
    batch = len(prompts)
    lengths = np.array([p[0].shape[1] for p in prompts], dtype=np.int64)
    states = []
    for prompt in prompts:
        width = prompt[0].shape[1]
        past = [np.zeros((1, 8, 0, 128), np.float32) for _ in pipe._past_names]
        states.append(pipe.talker_cache_step(prompt[0],
            np.broadcast_to(np.arange(width), (3, 1, width)).copy(),
            np.ones((1, width), np.int64), past))
    trailing = np.concatenate([p[1] for p in prompts], axis=0)
    vocab, eos, limit = prompts[0][2:5]
    rngs = [np.random.default_rng(seed) for seed in seeds]
    suppressed = [j for j in range(vocab - 1024, vocab) if j != eos]
    first_codes, output = [[] for _ in texts], [[] for _ in texts]
    done = np.zeros(batch, dtype=bool)
    for step in range(limit):
        codes = np.zeros((batch, N_GROUPS), np.int64)
        for i, p in enumerate(prompts):
            if done[i]: continue
            values = states[i][0][0, -1].astype(np.float64).copy()
            values[suppressed] = -np.inf
            values = _apply_repetition_penalty(values, first_codes[i], p[9])
            code = _sample(values, p[5], p[6], p[7], p[8], rngs[i])
            if code == eos:
                done[i] = True
            else:
                codes[i, 0] = code
                first_codes[i].append(code)
        if done.all(): break
        hidden = np.concatenate([state[1][:, -1] for state in states], axis=0).astype(np.float32)
        for group in range(1, N_GROUPS):
            groups = pipe.predict_residual(hidden, codes)
            for i, p in enumerate(prompts):
                if not done[i]:
                    codes[i, group] = _sample(groups[i, group - 1], p[10], p[11], p[12], p[13], rngs[i])
        for i in range(batch):
            if not done[i]: output[i].append(codes[i].copy())
        inputs = (pipe.step_embed(codes) + trailing)[:, None]
        for i in range(batch):
            if done[i]: continue
            total = int(lengths[i]) + step
            states[i] = pipe.talker_cache_step(inputs[i:i+1],
                np.broadcast_to(np.array([total]), (3, 1, 1)).copy(),
                np.ones((1, total + 1), np.int64), states[i][2])
        if (step + 1) % 25 == 0:
            print('  batch: ' + str(step + 1) + ' frames', flush=True)
    return [np.stack(codes).astype(np.int64) if codes else np.zeros((0, N_GROUPS), np.int64)
            for codes in output]
